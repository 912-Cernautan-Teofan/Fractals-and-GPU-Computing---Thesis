/*
#include "common/book.h"
#include <stdio.h>
#include "common/cpu_bitmap.h"
#include <cuda_runtime.h>

#define DIM 1000
#define ITERATIONS 500

#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb_image_write.h"

struct cuComplex
{
    float r, i;

    __device__ cuComplex(float a, float b) : r(a), i(b) {}

    __device__ float magnitude2(void)
    {
        return r * r + i * i;
    }

    __device__ cuComplex operator*(const cuComplex& a)
    {
        return cuComplex(r * a.r - i * a.i, i * a.r + r * a.i);
    }

    __device__ cuComplex operator+(const cuComplex& a)
    {
        return cuComplex(r + a.r, i + a.i);
    }
};

__device__ int julia(int x, int y)
{
    const float scale = 1.5;
    float jx = scale * (float)(DIM / 2 - x) / (DIM / 2);
    float jy = scale * (float)(DIM / 2 - y) / (DIM / 2);

    cuComplex c(-0.8, 0.156);
    cuComplex a(jx, jy);

    int i = 0;
    for (i = 0; i < ITERATIONS; i++)
    {
        a = a * a + c;
        if (a.magnitude2() > 1000)
        {
            break;
        }
    }

    return i;
}


__global__ void kernel(unsigned char* ptr) {
    // map from threadIdx/BlockIdx to pixel position
    int x = blockIdx.x;
    int y = blockIdx.y;
    int offset = x + y * gridDim.x;

    // calculate the Julia set value
    int juliaValue = julia(x, y);

    // normalize color: 255 for inside fractal (high iterations), 0 for escape (low iterations)
    unsigned char color = (unsigned char)(255 * (float)juliaValue / ITERATIONS);

    ptr[offset * 4 + 0] = color; // Red
    ptr[offset * 4 + 1] = color; // Green
    ptr[offset * 4 + 2] = color; // Blue
    ptr[offset * 4 + 3] = 255;   // Alpha
}



int main(void)
{
    CPUBitmap bitmap(DIM, DIM);
    unsigned char* dev_bitmap;

    HANDLE_ERROR(cudaMalloc((void**)&dev_bitmap, bitmap.image_size()));

    // Create CUDA events for timing
    cudaEvent_t start, stop;
    cudaEventCreate(&start);
    cudaEventCreate(&stop);

    // Record the start time
    cudaEventRecord(start, 0);

    // Launch the kernel
    dim3 grid(DIM, DIM);
    kernel << <grid, 1 >> > (dev_bitmap);

    // Record the stop time
    cudaEventRecord(stop, 0);

    // Wait for the events to complete
    cudaEventSynchronize(stop);

    // Calculate the elapsed time
    float milliseconds = 0;
    cudaEventElapsedTime(&milliseconds, start, stop);
    printf("Kernel execution time: %.2f ms\n", milliseconds);

    HANDLE_ERROR(cudaMemcpy(bitmap.get_ptr(), dev_bitmap, bitmap.image_size(), cudaMemcpyDeviceToHost));

    //bitmap.display_and_exit();

    char filename[64];
    snprintf(filename, sizeof(filename), "output_%dx%d_iter%d.png", DIM, DIM, ITERATIONS);
    stbi_write_png(filename, DIM, DIM, 4, bitmap.get_ptr(), DIM * 4);
    printf("Saved image: %s\n", filename);

    char openCmd[128];
    snprintf(openCmd, sizeof(openCmd), "start %s", filename);
    system(openCmd);  // Only works on Windows

    cudaFree(dev_bitmap);
    cudaEventDestroy(start);
    cudaEventDestroy(stop);

    return 0;
}
*/