#define WIN32
#include <stdio.h>
#include <assert.h>

// CUDA runtime
#include <cuda_runtime.h>

// Helper functions and utilities to work with CUDA
#include <helper_functions.h>

/////////////////////////////////////////////

void startAndHandleCmdLine(int argc, char** argv, int& devID)
{
    printf("[Matrix Multiply Using CUDA] - Starting...\n");

    if (checkCmdLineFlag(argc, (const char**)argv, "help") ||
        checkCmdLineFlag(argc, (const char**)argv, "?"))
    {
        printf("Usage -device=n (n >= 0 for deviceID)\n");
        printf("      -wA=WidthA -hA=HeightA (Width x Height of Matrix A)\n");
        printf("      -wB=WidthB -hB=HeightB (Width x Height of Matrix B)\n");
        printf("  Note: Outer matrix dimensions of A & B matrices must be equal.\n");

        exit(EXIT_SUCCESS);
    }

    if (checkCmdLineFlag(argc, (const char**)argv, "device"))
    {
        devID = getCmdLineArgumentInt(argc, (const char**)argv, "device");
        cudaSetDevice(devID);
    }
}

void handleErrors(int devID, cudaDeviceProp deviceProp)
{
    cudaError_t error;
    error = cudaGetDevice(&devID);

    if (error != cudaSuccess)
    {
        printf("cudaGetDevice returned error code %d, line(%d)\n", error, __LINE__);
    }

    error = cudaGetDeviceProperties(&deviceProp, devID);

    if (deviceProp.computeMode == cudaComputeModeProhibited)
    {
        fprintf(stderr, "Error: device is running in <Compute Mode Prohibited>, no threads can use ::cudaSetDevice().\n");
        exit(EXIT_SUCCESS);
    }

    if (error != cudaSuccess)
    {
        printf("cudaGetDeviceProperties returned error code %d, line(%d)\n", error, __LINE__);
    }
    else
    {
        printf("GPU Device %d: \"%s\" with compute capability %d.%d\n\n", devID, deviceProp.name, deviceProp.major, deviceProp.minor);
    }
}

void cmdLineDimUpdate(int argc, char** argv, dim3& dimsA, dim3& dimsB)
{
    // width of Matrix A
    if (checkCmdLineFlag(argc, (const char**)argv, "wA"))
    {
        dimsA.x = getCmdLineArgumentInt(argc, (const char**)argv, "wA");
    }

    // height of Matrix A
    if (checkCmdLineFlag(argc, (const char**)argv, "hA"))
    {
        dimsA.y = getCmdLineArgumentInt(argc, (const char**)argv, "hA");
    }

    // width of Matrix B
    if (checkCmdLineFlag(argc, (const char**)argv, "wB"))
    {
        dimsB.x = getCmdLineArgumentInt(argc, (const char**)argv, "wB");
    }

    // height of Matrix B
    if (checkCmdLineFlag(argc, (const char**)argv, "hB"))
    {
        dimsB.y = getCmdLineArgumentInt(argc, (const char**)argv, "hB");
    }

    if (dimsA.x != dimsB.y)
    {
        printf("Error: outer matrix dimensions must be equal. (%d != %d)\n",
            dimsA.x, dimsB.y);
        exit(EXIT_FAILURE);
    }

    printf("MatrixA(%d,%d), MatrixB(%d,%d)\n", dimsA.x, dimsA.y, dimsB.x, dimsB.y);
}

void allocateDeviceMemory(float*& d_A, float*& d_B, float*& d_C,
    unsigned int mem_size_A, unsigned int mem_size_B, unsigned int mem_size_C)
{
    cudaError_t error;

    error = cudaMalloc((void**)&d_A, mem_size_A);

    if (error != cudaSuccess)
    {
        printf("cudaMalloc d_A returned error code %d, line(%d)\n", error, __LINE__);
        exit(EXIT_FAILURE);
    }

    error = cudaMalloc((void**)&d_B, mem_size_B);

    if (error != cudaSuccess)
    {
        printf("cudaMalloc d_B returned error code %d, line(%d)\n", error, __LINE__);
        exit(EXIT_FAILURE);
    }

    error = cudaMalloc((void**)&d_C, mem_size_C);

    if (error != cudaSuccess)
    {
        printf("cudaMalloc d_C returned error code %d, line(%d)\n", error, __LINE__);
        exit(EXIT_FAILURE);
    }
}

void copyHostMemoryToDevice(float*& d_A, float*& d_B, float* h_A, float* h_B,
    unsigned int mem_size_A, unsigned int mem_size_B)
{
    cudaError_t error;
    error = cudaMemcpy(d_A, h_A, mem_size_A, cudaMemcpyHostToDevice);

    if (error != cudaSuccess)
    {
        printf("cudaMemcpy (d_A,h_A) returned error code %d, line(%d)\n", error, __LINE__);
        exit(EXIT_FAILURE);
    }

    error = cudaMemcpy(d_B, h_B, mem_size_B, cudaMemcpyHostToDevice);

    if (error != cudaSuccess)
    {
        printf("cudaMemcpy (d_B,h_B) returned error code %d, line(%d)\n", error, __LINE__);
        exit(EXIT_FAILURE);
    }
}

void constantInit(float* data, int size, float val)
{
    for (int i = 0; i < size; ++i)
    {
        data[i] = val;
    }
}

/////////////////////////////////////////////

template <int BLOCK_SIZE> __global__
void matrixMulCUDA(float* C, float* A, float* B, int N)
{
    // Block index
    int bx = blockIdx.x;
    int by = blockIdx.y;

    // Thread index
    int tx = threadIdx.x;
    int ty = threadIdx.y;

    int row = blockIdx.y * blockDim.y + threadIdx.y;
    int col = blockIdx.x * blockDim.x + threadIdx.x;

    // Csub is used to store the element of the block sub-matrix
    // that is computed by the thread
    float Csub = 0;

    for (int k = 0; k < N; k++) {
        // Accumulate results for a single element
        Csub += A[row * N + k] * B[k * N + col];
    }

    C[row * N + col] = Csub;
}

int matrixMultiply(int argc, char** argv, int block_size, dim3& dimsA, dim3& dimsB)
{
    // Allocate host memory for matrices A, B and C
    unsigned int size_A = dimsA.x * dimsA.y;
    unsigned int mem_size_A = sizeof(float) * size_A;
    float* h_A = (float*)malloc(mem_size_A);
    unsigned int size_B = dimsB.x * dimsB.y;
    unsigned int mem_size_B = sizeof(float) * size_B;
    float* h_B = (float*)malloc(mem_size_B);
    dim3 dimsC(dimsB.x, dimsA.y, 1);
    unsigned int mem_size_C = dimsC.x * dimsC.y * sizeof(float);
    float* h_C = (float*)malloc(mem_size_C);

    if (h_C == NULL)
    {
        fprintf(stderr, "Failed to allocate host matrix C!\n");
        exit(EXIT_FAILURE);
    }

    // Initialize host memory
    const float valB = 0.01f;
    constantInit(h_A, size_A, 1.0f);
    constantInit(h_B, size_B, valB);

    // Allocate device memory
    float* d_A, * d_B, * d_C;
    allocateDeviceMemory(d_A, d_B, d_C, mem_size_A, mem_size_B, mem_size_C);

    // Copy host memory to device
    copyHostMemoryToDevice(d_A, d_B, h_A, h_B, mem_size_A, mem_size_B);

    // Setup execution parameters
    dim3 threads(block_size, block_size);
    dim3 grid(dimsB.x / threads.x, dimsA.y / threads.y);

    // Create and start timer
    printf("Computing result using CUDA Kernel...\n");

    // Performs warmup operation using matrixMul CUDA kernel
    /*
    if (block_size == 16)
    {
        matrixMulCUDA<16> << < grid, threads >> > (d_C, d_A, d_B, dimsA.x, dimsB.x);
    }
    else
    {
        matrixMulCUDA<32> << < grid, threads >> > (d_C, d_A, d_B, dimsA.x, dimsB.x);
    }

    printf("done\n");
    */

    cudaDeviceSynchronize();

    // Allocate CUDA events that we'll use for timing
    cudaEvent_t start;
    cudaError_t error;
    error = cudaEventCreate(&start);

    if (error != cudaSuccess)
    {
        fprintf(stderr, "Failed to create start event (error code %s)!\n", cudaGetErrorString(error));
        exit(EXIT_FAILURE);
    }

    cudaEvent_t stop;
    error = cudaEventCreate(&stop);

    if (error != cudaSuccess)
    {
        fprintf(stderr, "Failed to create stop event (error code %s)!\n", cudaGetErrorString(error));
        exit(EXIT_FAILURE);
    }

    // Record the start event
    error = cudaEventRecord(start, NULL);

    if (error != cudaSuccess)
    {
        fprintf(stderr, "Failed to record start event (error code %s)!\n", cudaGetErrorString(error));
        exit(EXIT_FAILURE);
    }

    // Execute the kernel
    int nIter = 300;

    for (int j = 0; j < nIter; j++)
    {
        if (block_size == 16)
        {
            matrixMulCUDA<16> << < grid, threads >> > (d_C, d_A, d_B, dimsA.x);
        }
        else
        {
            matrixMulCUDA<32> << < grid, threads >> > (d_C, d_A, d_B, dimsA.x);
        }
    }

    // Record the stop event
    error = cudaEventRecord(stop, NULL);

    if (error != cudaSuccess)
    {
        fprintf(stderr, "Failed to record stop event (error code %s)!\n", cudaGetErrorString(error));
        exit(EXIT_FAILURE);
    }

    // Wait for the stop event to complete
    error = cudaEventSynchronize(stop);

    if (error != cudaSuccess)
    {
        fprintf(stderr, "Failed to synchronize on the stop event (error code %s)!\n", cudaGetErrorString(error));
        exit(EXIT_FAILURE);
    }

    float msecTotal = 0.0f;
    error = cudaEventElapsedTime(&msecTotal, start, stop);

    if (error != cudaSuccess)
    {
        fprintf(stderr, "Failed to get time elapsed between events (error code %s)!\n", cudaGetErrorString(error));
        exit(EXIT_FAILURE);
    }

    // Compute and print the performance
    float msecPerMatrixMul = msecTotal / nIter;
    double flopsPerMatrixMul = 2.0 * (double)dimsA.x * (double)dimsA.y * (double)dimsB.x;
    double gigaFlops = (flopsPerMatrixMul * 1.0e-9f) / (msecPerMatrixMul / 1000.0f);
    printf(
        "Performance= %.2f GFlop/s, Time= %.3f msec, Size= %.0f Ops, WorkgroupSize= %u threads/block\n",
        gigaFlops,
        msecPerMatrixMul,
        flopsPerMatrixMul,
        threads.x * threads.y);

    // Copy result from device to host
    error = cudaMemcpy(h_C, d_C, mem_size_C, cudaMemcpyDeviceToHost);

    if (error != cudaSuccess)
    {
        printf("cudaMemcpy (h_C,d_C) returned error code %d, line(%d)\n", error, __LINE__);
        exit(EXIT_FAILURE);
    }

    printf("Checking computed result for correctness: ");
    bool correct = true;

    for (int i = 0; i < (int)(dimsC.x * dimsC.y); i++)
    {
        if (fabs(h_C[i] - (dimsA.x * valB)) > 1e-5)
        {
            printf("Error! Matrix[%05d]=%.8f, ref=%.8f error term is > 1e-5\n", i, h_C[i], dimsA.x * valB);
            correct = false;
        }
    }

    printf("%s\n", correct ? "OK" : "FAIL");

    // Clean up memory
    free(h_A);
    free(h_B);
    free(h_C);
    cudaFree(d_A);
    cudaFree(d_B);
    cudaFree(d_C);

    printf("\nNote: For peak performance, please refer to the matrixMulCUBLAS example.\n");

    cudaDeviceReset();

    if (correct)
    {
        return EXIT_SUCCESS;
    }
    else
    {
        return EXIT_FAILURE;
    }
}

/////////////////////////////////////////////

int main(int argc, char** argv)
{
    // By default, we use device 0, otherwise we override the device ID based on what is provided at the command line
    int devID = 0;
    startAndHandleCmdLine(argc, argv, devID);

    cudaDeviceProp deviceProp;
    handleErrors(devID, deviceProp);

    // Use a larger block size for Fermi and above
    int block_size = (deviceProp.major < 2) ? 16 : 32;

    dim3 dimsA(5 * 2 * block_size, 5 * 2 * block_size, 1);
    dim3 dimsB(5 * 2 * block_size, 5 * 2 * block_size, 1);
    cmdLineDimUpdate(argc, argv, dimsA, dimsB);

    int matrix_result = matrixMultiply(argc, argv, block_size, dimsA, dimsB);

    exit(matrix_result);
}
