
#include <cuda_block_matrix_multiplier.hpp>
#include <cassert>

// CUDA code from: https://docs.nvidia.com/cuda/cuda-c-programming-guide/index.html

#define BLOCK_SIZE 16

// Get a matrix element
__device__ float GetElement(const Matrix A, int row, int col)
{
    return A.elements[row * A.stride + col];
}

// Set a matrix element
__device__ void SetElement(Matrix A, int row, int col,
                           float value)
{
    A.elements[row * A.stride + col] = value;
}

// Get the BLOCK_SIZExBLOCK_SIZE sub-matrix Asub of A that is
// located col sub-matrices to the right and row sub-matrices down
// from the upper-left corner of A
__device__ Matrix GetSubMatrix(Matrix A, int row, int col)
{
    Matrix Asub;
    Asub.width = BLOCK_SIZE;
    Asub.height = BLOCK_SIZE;
    Asub.stride = A.stride;
    Asub.elements = &A.elements[A.stride * BLOCK_SIZE * row + BLOCK_SIZE * col];
    return Asub;
}

__global__ void MatMulKernel(Matrix A, Matrix B, Matrix C)
{
    // Block row and column
    int blockRow = blockIdx.y;
    int blockCol = blockIdx.x;

    // Each thread block computes one sub-matrix Csub of C
    Matrix Csub = GetSubMatrix(C, blockRow, blockCol);

    // Each thread computes one element of Csub
    // by accumulating results into Cvalue
    float Cvalue = 0;

    // Thread row and column within Csub
    int row = threadIdx.y;
    int col = threadIdx.x;

    // Loop over all the sub-matrices of A and B that are
    // required to compute Csub
    // Multiply each pair of sub-matrices together
    // and accumulate the results
    for (int m = 0; m < (A.width / BLOCK_SIZE); ++m)
    {

        // Get sub-matrix Asub of A
        Matrix Asub = GetSubMatrix(A, blockRow, m);

        // Get sub-matrix Bsub of B
        Matrix Bsub = GetSubMatrix(B, m, blockCol);

        // Shared memory used to store Asub and Bsub respectively
        __shared__ float As[BLOCK_SIZE][BLOCK_SIZE];
        __shared__ float Bs[BLOCK_SIZE][BLOCK_SIZE];

        // Load Asub and Bsub from device memory to shared memory
        // Each thread loads one element of each sub-matrix
        As[row][col] = GetElement(Asub, row, col);
        Bs[row][col] = GetElement(Bsub, row, col);

        // Synchronize to make sure the sub-matrices are loaded
        // before starting the computation
        __syncthreads();

        // Multiply Asub and Bsub together
        for (int e = 0; e < BLOCK_SIZE; ++e)
            Cvalue += As[row][e] * Bs[e][col];

        // Synchronize to make sure that the preceding
        // computation is done before loading two new
        // sub-matrices of A and B in the next iteration
        __syncthreads();
    }

    // Write Csub to device memory
    // Each thread writes one element
    SetElement(Csub, row, col, Cvalue);
}

template <long N>
CudaBlockMatrixMultipler<N>::~CudaBlockMatrixMultipler()
{
    cudaFree(d_A.elements);
    cudaFree(d_B.elements);
    cudaFree(d_C.elements);
}

template <long N>
void CudaBlockMatrixMultipler<N>::multiply(float (&A)[N][N], float (&B)[N][N], float (&C)[N][N])
{
    // Load A and B to device memory
    d_A.width = d_A.stride = N;
    d_A.height = N;
    size_t size = N * N * sizeof(float);
    assert(cudaSuccess == cudaMalloc(&d_A.elements, size));
    assert(cudaSuccess == cudaMemcpy(d_A.elements, A, size, cudaMemcpyHostToDevice));

    d_B.width = d_B.stride = N;
    d_B.height = N;
    size = N * N * sizeof(float);
    assert(cudaSuccess == cudaMalloc(&d_B.elements, size));
    assert(cudaSuccess == cudaMemcpy(d_B.elements, B, size, cudaMemcpyHostToDevice));

    // Allocate C in device memory
    d_C.width = d_C.stride = N;
    d_C.height = N;
    size = N * N * sizeof(float);
    assert(cudaSuccess == cudaMalloc(&d_C.elements, size));

    // Invoke kernel
    dim3 dimBlock(BLOCK_SIZE, BLOCK_SIZE);
    dim3 dimGrid(N / dimBlock.x, N / dimBlock.y);
    MatMulKernel<<<dimGrid, dimBlock>>>(d_A, d_B, d_C);

    // Read C from device memory
    assert(cudaSuccess == cudaMemcpy(C, d_C.elements, size, cudaMemcpyDeviceToHost));
}

template class CudaBlockMatrixMultipler<1024>;
