# try all static builds for deps

#!/bin/bash
set -x -e

function retry {
  local retries=$1
  shift

  local count=0
  until "$@"; do
    exit=$?
    wait=$((2 ** $count))
    count=$(($count + 1))
    if [ $count -lt $retries ]; then
      echo "Retry $count/$retries exited $exit, retrying in $wait seconds..."
      sleep $wait
    else
      echo "Retry $count/$retries exited $exit, no more retries left."
      return $exit
    fi
  done
  return 0
}

CURRDIR=$(pwd)
ls -ltrh $CURRDIR

NUM_LOGICAL_CPUS=$(sysctl -n hw.logicalcpu)
echo "Number of logical CPUs is: ${NUM_LOGICAL_CPUS}"

brew update
#brew upgrade
brew install wget python cmake || true
# TODO: try without brew install of boost, but use version below

brew install llvm libomp

# git cmake boost eigen freeimage glog gflags suite-sparse ceres-solver glew cgal qt5


# ---- Install glog -----
cd $CURRDIR
git clone https://github.com/google/glog.git
cd glog
ls -ltrh .
mkdir build && cd build && cmake ..
make -j$NUM_LOGICAL_CPUS
make install

# -------- Install GFlags ------
cd $CURRDIR
git clone https://github.com/gflags/gflags.git
cd gflags
ls -ltrh .
mkdir build && cd build && cmake ..
make -j$NUM_LOGICAL_CPUS
make install 


# -------- Install Eigen ------
cd $CURRDIR
# Using Eigen 3.3, not Eigen 3.4
wget https://gitlab.com/libeigen/eigen/-/archive/3.3.9/eigen-3.3.9.tar.gz
tar -xvzf eigen-3.3.9.tar.gz
# While Eigen is a header-only library, it still has to be built!
# Creates Eigen3Config.cmake from Eigen3Config.cmake.in
cd /eigen-3.3.9
mkdir build
cd build
cmake ..


### ------ Build FreeImage from source and install --------------------
cd $CURRDIR
wget http://downloads.sourceforge.net/freeimage/FreeImage3180.zip
unzip FreeImage3180.zip
cd FreeImage
make
make install






brew info gcc
brew upgrade gcc
brew info gcc

echo 'export PATH="/usr/local/opt/qt@5/bin:$PATH"' >> /Users/runner/.bash_profile



# Build Boost staticly
mkdir -p boost_build
cd boost_build
retry 3 wget https://boostorg.jfrog.io/artifactory/main/release/1.73.0/source/boost_1_73_0.tar.gz
tar xzf boost_1_73_0.tar.gz
cd boost_1_73_0
./bootstrap.sh --prefix=$CURRDIR/boost_install --with-libraries=serialization,filesystem,thread,system,atomic,date_time,timer,chrono,program_options,regex clang-darwin
./b2 -j$(sysctl -n hw.logicalcpu) cxxflags="-fPIC" runtime-link=static variant=release link=static install



# ----------- Install CERES solver -------------------------------------------------------
cd $CURRDIR
git clone https://ceres-solver.googlesource.com/ceres-solver
cd ceres-solver
git checkout $(git describe --tags) # Checkout the latest release
mkdir build
cd build
cmake .. -DBUILD_TESTING=OFF \
         -DBUILD_EXAMPLES=OFF \
         -DEigen3_DIR=$CMAKE_PREFIX_PATH
make -j$(nproc)
make install






echo "CURRDIR is: ${CURRDIR}"

cd $CURRDIR
mkdir -p $CURRDIR/wheelhouse_unrepaired
mkdir -p $CURRDIR/wheelhouse

ORIGPATH=$PATH

PYTHON_LIBRARY=$(cd $(dirname $0); pwd)/libpython-not-needed-symbols-exported-by-interpreter
touch ${PYTHON_LIBRARY}

declare -a PYTHON_VERS=( $1 )

# Get the python version numbers only by splitting the string
split_array=(${PYTHON_VERS//@/ })
VERSION_NUMBER=${split_array[1]}

git clone https://github.com/colmap/colmap.git

sed -i -e 's/Qt5 5.4/Qt5 5.15.2/g' colmap/CMakeLists.txt

for compiler in cc c++ gcc g++ clang clang++
do
    which $compiler
    $compiler --version
done

# Compile wheels
for PYVER in ${PYTHON_VERS[@]}; do
    PYBIN="/usr/local/opt/$PYVER/bin"

    PYTHONVER="$(basename $(dirname $PYBIN))"
    BUILDDIR="$CURRDIR/colmap_$PYTHONVER/colmap_build"
    mkdir -p $BUILDDIR
    cd $BUILDDIR
    export PATH=$PYBIN:$PYBIN:/usr/local/bin:$ORIGPATH
    # Install `delocate` -- OSX equivalent of `auditwheel` -- see https://pypi.org/project/delocate/ for more details
    "${PYBIN}/pip3" install delocate==0.8.2
    
    PYTHON_EXECUTABLE=${PYBIN}/python3
    
    ls -ltrh /usr/local
    ls -ltrh /usr/local/opt
    
    cd $CURRDIR
    cd colmap
    git checkout dev
    mkdir build_$PYTHONVER
    cd build_$PYTHONVER
    cmake .. -DQt5_DIR=/usr/local/opt/qt@5/lib/cmake/Qt5

    # examine exit code of last command
    ec=$?

    if [ $ec -ne 0 ]; then
        echo "Error:"
        cat ./CMakeCache.txt
        exit $ec
    fi
    set -e -x

    make -j $NUM_LOGICAL_CPUS install
    sudo make install
    
    cd $CURRDIR
    git clone --recursive https://github.com/mihaidusmanu/pycolmap.git
    cd $CURRDIR/pycolmap
    # custum version has qt cmake path arg
    cp $CURRDIR/setup.py setup.py
    cat setup.py

    # flags must be passed, to avoid the issue: `Unsupported compiler -- pybind11 requires C++11 support!`
    # see https://github.com/quantumlib/qsim/issues/242 for more details
    CC=/usr/local/opt/llvm/bin/clang CXX=/usr/local/opt/llvm/bin/clang++ LDFLAGS=-L/usr/local/opt/libomp/lib "${PYBIN}/python3" setup.py bdist_wheel
    cp ./dist/*.whl $CURRDIR/wheelhouse_unrepaired
done

# Bundle external shared libraries into the wheels
for whl in $CURRDIR/wheelhouse_unrepaired/*.whl; do
    delocate-listdeps --all "$whl"
    delocate-wheel -w "$CURRDIR/wheelhouse" -v "$whl"
    rm $whl
done
