# Big data analysis - application of Online Statistics
How to deal with big data, with 'our computers' </br>
[Application in julia - OnlineStats](https://joshday.github.io/OnlineStats.jl/latest/bigdata/) </br>
[Application in julia - OnlineStats: dispatch](https://juliafolds.github.io/data-parallelism/tutorials/quick-introduction/) </br>
[Julia: multiple dispatch](https://docs.julialang.org/en/v1/manual/distributed-computing/)

In the application, I am using geospatial data

<img src="https://media.giphy.com/media/dWTBGOR6sLLWQvZZ21/giphy.gif" width=300 align=center>

## System setup

First, check the RAM space - how much data intake this computer can have.


```julia
print("$(round(Sys.free_memory()/2^20 * 0.00104858, digits = 1)) GB memory free")
```

    3.5 GB memory free

For the actual work, check how many processors are available, along with their status


```julia
Sys.cpu_info()
```




    12-element Vector{Base.Sys.CPUinfo}:
     Intel(R) Core(TM) i7-8850H CPU @ 2.60GHz: 
            speed         user         nice          sys         idle          irq
         2592 MHz    1066203            0      1657546     37959093       554734  ticks
     Intel(R) Core(TM) i7-8850H CPU @ 2.60GHz: 
            speed         user         nice          sys         idle          irq
         2592 MHz     631468            0       520718     39530593        75343  ticks
     Intel(R) Core(TM) i7-8850H CPU @ 2.60GHz: 
            speed         user         nice          sys         idle          irq
         2592 MHz    3287468            0      1173187     36222125        18796  ticks
     Intel(R) Core(TM) i7-8850H CPU @ 2.60GHz: 
            speed         user         nice          sys         idle          irq
         2592 MHz    1250031            0       607234     38825500         6078  ticks
     Intel(R) Core(TM) i7-8850H CPU @ 2.60GHz: 
            speed         user         nice          sys         idle          irq
         2592 MHz    2266031            0       801421     37615328        16171  ticks
     Intel(R) Core(TM) i7-8850H CPU @ 2.60GHz: 
            speed         user         nice          sys         idle          irq
         2592 MHz     925015            0       420765     39336984         7046  ticks
     Intel(R) Core(TM) i7-8850H CPU @ 2.60GHz: 
            speed         user         nice          sys         idle          irq
         2592 MHz    1650609            0       626437     38405718        12062  ticks
     Intel(R) Core(TM) i7-8850H CPU @ 2.60GHz: 
            speed         user         nice          sys         idle          irq
         2592 MHz    1011515            0       319390     39351859        10156  ticks
     Intel(R) Core(TM) i7-8850H CPU @ 2.60GHz: 
            speed         user         nice          sys         idle          irq
         2592 MHz    1382093            0       569515     38731156        13375  ticks
     Intel(R) Core(TM) i7-8850H CPU @ 2.60GHz: 
            speed         user         nice          sys         idle          irq
         2592 MHz     931281            0       330937     39420406         9265  ticks
     Intel(R) Core(TM) i7-8850H CPU @ 2.60GHz: 
            speed         user         nice          sys         idle          irq
         2592 MHz    1351390            0       561984     38769390        13343  ticks
     Intel(R) Core(TM) i7-8850H CPU @ 2.60GHz: 
            speed         user         nice          sys         idle          irq
         2592 MHz     819796            0       430109     39432859         9343  ticks



I am letting julia know that I will have 8 processors ready for work. </br>
Import relevant packages needed, in the process I am going to dispatch the packages to all processors for them to work with


```julia
using CSV, DataFrames, OnlineStats, Plots;
using Distributed
addprocs(8)

@everywhere using CSV, DataFrames, OnlineStats, Plots;
```

    ┌ Info: Precompiling OnlineStats [a15396b6-48d5-5d58-9928-6d29437db91e]
    └ @ Base loading.jl:1317
    


```julia
print("$(round(filesize(str_data) / 1e9, digits = 1)) GB file size")
```

    16.3 GB file size

Given my RAM size, I cannot do I/O method of pulling all data in for data manipulation.


```julia
# How many rows of data?
@everywhere function countcsvlines(file)
    n = 0
    for row in CSV.Rows(file; resusebuffer=true)
        n += 1
    end
    return n
end
@everywhere function commas(num::Integer)
    str = string(num)
    return replace(str, r"(?<=[0-9])(?=(?:[0-9]{3})+(?![0-9]))" => ",")
end

@everywhere ncount = countcsvlines(str_data);
print("There are $(commas(ncount)) rows in this dataset.")
```

    There are 34,195,673 rows in this dataset.

## Regarding the online (statistics) algorithm
"In computer science, an online algorithm is one that can process its input piece-by-piece in a serial fashion, i.e., in the order that the input is fed to the algorithm, without having the entire input available from the start."

Ultimatley using O(1) of memory, instead of O(n)

<img src="https://user-images.githubusercontent.com/8075494/57345083-95079780-7117-11e9-81bf-71b0469f04c7.png" width=300 align=center>

## Stream the data

Based on julia's CSV stream and online statistics operations, by in-row replacing and reusing buffer so I am freeing up spaces. </br>
For example, I want to know 1st to 4th centered moments (mean, standard deviation, skewness, and kurtosis) of the sales volume statistics


```julia
@time begin # am measuring time it takes to go through every single row
    rows = CSV.Rows(str_data; header = 1, normalizenames = true, reusebuffer = true)
    m = Moments() # save the moments

    foreach(rows) do linrows
        val_sales =  linrows.sales
        if !ismissing(linrows.class)
            fit!(m, parse(Float64, val_sales))
        end
    end
end
```

    132.534417 seconds (100.67 M allocations: 2.502 GiB, 10.60% gc time, 2.84% compilation time)
    

Check to see if all moments are calculated accordingly


```julia
println("Mean: $(mean(m))")
println("Variance: $(var(m))")
println("Standard deviaiton: $(std(m))")
println("Skewness: $(skewness(m))")
println("Kurtosis (fat tail): $(kurtosis(m))")
```

    Mean: 1.5748347481818595e6
    Variance: 5.4761819219123224e16
    Standard deviaiton: 2.3401243389854997e8
    Skewness: 930.1491906257752
    Kurtosis (fat tail): 1.356500565269967e6
    

## I am greedy - parallel process?
To do so, I need to divde the data in chuncks for each operation to take 


```julia
@everywhere nchunk = 6_000_000;
@everywhere nvec = vcat(2:nchunk:ncount); # excluding the column headers
@everywhere n_khist = 30; # K-histogram values to be used for plotting
```


```julia
@time begin
    # Might be a need to @sync in case the partitioned opeartions are lost
    s = @distributed merge for iter in 1:length(nvec)
        rows = CSV.Rows(str_data; skipto = nvec[iter], limit = nchunk, header = 1, 
                        normalizenames = true, reusebuffer = true)
        # Do the same operation
        o = Moments()
        
        foreach(rows) do linrows
            val_sales = linrows.sales
            if !ismissing(linrows.class)
                fit!(o, parse(Float64, val_sales))
            end
        end
        # merge function requires the last output
        o
    end
end
```

     79.866904 seconds (74.17 k allocations: 4.235 MiB, 5.22% compilation time)
    




    Moments: n=34195673 | value=[1.57483e6, 5.47643e16, 1.19201e28, 4.06803e39]



Observing the (same) result, for the half of the time! </br>
(Note that moments are 'centered' when calculated below)


```julia
println("Mean: $(mean(s))")
println("Variance: $(var(s))")
println("Standard deviaiton: $(std(s))")
println("Skewness: $(skewness(s))")
println("Kurtosis (fat tail): $(kurtosis(s))")
```

    Mean: 1.5748347481818558e6
    Variance: 5.4761819219116424e16
    Standard deviaiton: 2.3401243389853546e8
    Skewness: 930.1491906262361
    Kurtosis (fat tail): 1.3565005652702223e6
    


```julia
# Moment calculation - for example of skewness
μ = 1.57483e6
σ = sqrt(5.47643e16)
mom_3 = 1.19201e28

((mom_3) - (3*μ*σ^2) - μ^3)/σ^3
```




    930.0882558638556



Mathematical proof below:

$\mathbb{E}[(X - \mu)^3] = \mathbb{E}[\mathbb{E}[X^3] - 3\mu \mathbb{E}[X^2] + 3\mu ^2 \mathbb{E}[X] - \mu ^3]$

$\mathbb{E}[(X - \mu)^3] = \mathbb{E}[\mathbb{E}[X^3] - 3\mu \mathbb{E}[X^2] + 3\mu ^2 \mu - \mu ^3]$

With expected value logics, the equation becomes,

$\mathbb{E}[X^3] - 3\mu \mathbb{E}[X^2] +2 \mu ^3$

Applying second moment calculation: $\mathbb{E}[X^2] = \sigma ^2 + \mu ^2$, assuming lack of covariability

$\mathbb{E}[(X - \mu)^3] = \mathbb{E}[X^3] - 3\mu \sigma ^2 - \mu ^3$

Applying equation

$skewness(x) = \mathbb{E}[(\frac{X - \mu}{\sigma})^3]$

We get,

$skewness(x) = \frac{\mathbb{E}[X^3] - 3\mu \sigma ^2 - \mu ^3}{\sigma ^3}$

Same can be done with Kurtosis calculation (fyi - Kurtosis for normal distribution is 3)

If you want to [pull out your paper and pencil](https://www.randomservices.org/random/expect/Skew.html) </br>
<img src="https://media.giphy.com/media/JVnLiRIsioEVO/giphy.gif" width=300 align=center>


## Future state
[julia in GPU computing framework](https://cuda.juliagpu.org/stable/tutorials/introduction/)
