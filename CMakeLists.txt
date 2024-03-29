
cmake_minimum_required(VERSION 3.10.0)

project(benchmark_matrix_multiply LANGUAGES CXX CUDA)

find_library(CUDART_LIBRARY cudart ${CMAKE_CUDA_IMPLICIT_LINK_DIRECTORIES})
find_library(CUBLAS_LIBRARY cublas ${CMAKE_CUDA_IMPLICIT_LINK_DIRECTORIES})
find_library(OPENCL_LIBRARY OpenCL ${CMAKE_CUDA_IMPLICIT_LINK_DIRECTORIES})

add_executable(
    ${PROJECT_NAME}
    src/matrix_multiply.cpp
    src/block_matrix_multiplier.cpp
    src/cublas_matrix_multiplier.cu
    src/standard_matrix_multiplier.cpp
    src/opencl_matrix_multiplier.cpp
    src/cuda_block_matrix_multiplier.cu
)

set_target_properties(${PROJECT_NAME} PROPERTIES
    CXX_STANDARD 17
    CXX_STANDARD_REQUIRED ON
    CUDART_LIBRARY cudart)

target_include_directories(${PROJECT_NAME} PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    ${CMAKE_CUDA_TOOLKIT_INCLUDE_DIRECTORIES}
)

target_link_libraries(
    ${PROJECT_NAME}
    ${CUDART_LIBRARY}
    ${CUBLAS_LIBRARY}
    ${OPENCL_LIBRARY}
)

configure_file(resources/matrix_multiply_kernel.cl matrix_multiply_kernel.cl COPYONLY)
configure_file(resources/1024_matrix_data 1024_matrix_data COPYONLY)
