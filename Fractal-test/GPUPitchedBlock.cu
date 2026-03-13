#include "common/book.h"
#include <stdio.h>
#include "common/cpu_bitmap.h"
#include <cuda_runtime.h>
#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb_image_write.h"

#define DIM 8000
#define ITERATIONS 1000
#define BLOCKSIZE 16

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
    const float scale = 1;
    float jx = scale * (float)(DIM / 2 - x) / (DIM / 2);
    float jy = scale * (float)(DIM / 2 - y) / (DIM / 2);

    cuComplex c(-0.5, 0);
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

__global__ void kernel(unsigned char* ptr, size_t pitch) 
{

    int x = threadIdx.x + blockIdx.x * blockDim.x;
    int y = threadIdx.y + blockIdx.y * blockDim.y;

    if (x < DIM && y < DIM) {
        unsigned char* row = (unsigned char*)((char*)ptr + y * pitch);
        int offset = x * 4;

        int value = julia(x, y);
        float norm = (float)value / ITERATIONS;

        // High contrast colors
        row[offset + 0] = (unsigned char)(255 * norm);                  // R
        row[offset + 1] = (unsigned char)(255 * sqrtf(norm));           // G
        row[offset + 2] = (unsigned char)(255 * sqrtf(sqrtf(norm)));    // B
        row[offset + 3] = 255;                                          // Alpha
    }
}

int main(void)
{
    CPUBitmap bitmap(DIM, DIM);
    unsigned char* dev_bitmap;
    size_t pitch;

    cudaMallocPitch(&dev_bitmap, &pitch, DIM * 4, DIM);

    cudaEvent_t start, stop;
    cudaEventCreate(&start);
    cudaEventCreate(&stop);

    cudaEventRecord(start, 0);

    // Use BLOCKSIZE macro
    dim3 blockSize(BLOCKSIZE, BLOCKSIZE);
    dim3 gridSize((DIM + BLOCKSIZE - 1) / BLOCKSIZE, (DIM + BLOCKSIZE - 1) / BLOCKSIZE);

    kernel << <gridSize, blockSize >> > (dev_bitmap, pitch);

    cudaEventRecord(stop, 0);
    cudaEventSynchronize(stop);

    float milliseconds = 0;
    cudaEventElapsedTime(&milliseconds, start, stop);
    printf("Kernel execution time: %.2f ms\n", milliseconds);

    cudaMemcpy2D(bitmap.get_ptr(), DIM * 4, dev_bitmap, pitch, DIM * 4, DIM, cudaMemcpyDeviceToHost);

    char filename[64];
    snprintf(filename, sizeof(filename), "fractal_%dx%d_iter%d_block%d.png", DIM, DIM, ITERATIONS, BLOCKSIZE);
    stbi_write_png(filename, DIM, DIM, 4, bitmap.get_ptr(), DIM * 4);
    printf("Saved image to %s\n", filename);

    char openCmd[128];
    snprintf(openCmd, sizeof(openCmd), "start %s", filename);
    system(openCmd);  // Only works on Windows

    cudaFree(dev_bitmap);
    cudaEventDestroy(start);
    cudaEventDestroy(stop);

    return 0;
}