# Big data processing in low-capacity machines
This repository contains julia programming codes to process big data (+2 TB) in highest capacity - leveraging parallel and in-memory processing, such that the kind of volume of data can be process with our common low-capcity computers.

This code gives example script flows, processing [Safegraph](https://www.safegraph.com/) foot=traffic data as an example, specifically geospatial pattern data.

- [x] Parellel processing and processor-level flow adjustments to distribute works to multiple processors for faster computation
- [x] Example of Online Algorithm [leveraging OnlineStats.jl](https://github.com/joshday/OnlineStats.jl) to handle and in-memory process big data in local small=capacity machines (results based on randomly generated data sales, employment, and square footage geospatial data based on imputation of survey of businesses - publicly available [here](https://www.census.gov/programs-surveys/susb.html))
