
## pycolmap Python Wheels

This repository provides functionality to build Python wheels for COLMAP.

`pycolmap` requires building COLMAP from source, and also a system-wide installation of COLMAP, along with locally building and installing `pycolmap`.
This requires a lot of dependencies. This library makes installation as simple as `pip install pycolmap`.

`pycolmap` exposes Fundamental matrix, Essential matrix, and absolute pose estimators via a Pybind wrapper. These high-performance estimators use LORANSAC.

## License
This code is governed by its own license, and if you use pycolmp and COLMAP, the those respective licenses also apply. See [here](https://github.com/colmap/colmap/blob/dev/README.md) for more details.

## Citing this work


@misc{Lambert21_pycolmapwheelbuilder,
    author = {John Lambert},
    title = {Pycolmap Wheelbuilder},
    howpublished={\url{https://github.com/johnwlambert/pycolmap-wheels}},
    year = {2021}
}

This work builds off of `pycolmap` and `COLMAP`, which should be cited as well:

pycolmap: https://github.com/mihaidusmanu/pycolmap

COLMAP: https://github.com/colmap/colmap
