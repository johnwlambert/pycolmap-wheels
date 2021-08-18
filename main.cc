#include <pybind11/pybind11.h>

namespace py = pybind11;

#include "absolute_pose.cc"
#include "essential_matrix.cc"
#include "fundamental_matrix.cc"
#include "transformations.cc"
#include "sift.cc"

PYBIND11_MODULE(pycolmap, m) {
    m.doc() = "COLMAP plugin";

    // Essential matrix.
    m.def("essential_matrix_estimation", &essential_matrix_estimation,
          py::arg("points2D1"), py::arg("points2D2"),
          py::arg("camera_dict1"), py::arg("camera_dict2"),
          py::arg("max_error_px") = 4.0,
          "LORANSAC + 5-point algorithm.");

    // Fundamental matrix.
    m.def("fundamental_matrix_estimation", &fundamental_matrix_estimation,
          py::arg("points2D1"), py::arg("points2D2"),
          py::arg("max_error_px") = 4.0,
          "LORANSAC + 7-point algorithm.");

    // todo: add SIFT and absolute pose estimation to API, also.
}
