
#include <stdlib.h>
#include <time.h>

int main()
{
    srand(clock());

    int arr[] = {2, 1, 3, 4, 5, 6, 7, 8, 9, 10};
    int size = sizeof arr / sizeof arr[0];
    int newtbl[size];
    int shrunksize, n, r, m;
    clock_t start = clock();

    int count = 0;
    while (!sorted(arr, size))
    {
        count++;
        shrunksize = size;
        for (n = 0; n < size; n++)
        {
            r = rand() % shrunksize--;              // selects a random item in array
            newtbl[n] = arr[r];                         // copies it to new array
            for (m = r; m <= shrunksize; m++)       // moves items in old array down
                arr[m] = arr[m + 1];
        }

        memcpy(arr, newtbl, sizeof arr);                // copies new array to old array
    }
    clock_t elapsed = clock() - start;

    for (int i = 0; i < size; i++)
        printf("%d\n", arr[i]);

    printf("took %f seconds and %d iterations\n", (double)elapsed / CLOCKS_PER_SEC, count);
    printf("%d operation per second\n", count / elapsed * CLOCKS_PER_SEC);

    return 0;
}

int sorted(int* arr, size_t size)
{
    for (int i = 1; i < size; i++)
        if (*(arr + i - 1) > *(arr + i))
            return 0;
    return 1;
}
