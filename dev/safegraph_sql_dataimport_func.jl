## Function for creating data structure of popularity by day
function cbg_json_ary(df, icol)
    iter = 1;

    temp_json_ele = deepcopy(df[iter, icol]);
    temp_id = deepcopy(DataFrame(df[iter, ["safegraph_place_id",
                                           "date_range_start",
                                           "date_range_end"]]))

    ary_visit_home = DataFrame(JSON3.read(temp_json_ele))
    ary_visit_home = hcat(temp_id, ary_visit_home)

    ncount = size(df, 1)
    #ncount = 10; # NOTE: FOR BUILDING OUT CODE - NEED TO CHANGE FOR ROLLOUT
    for iter = 2:ncount
        temp_json_ele = deepcopy(df[iter, icol]);
        temp_id = deepcopy(DataFrame(df[iter, ["safegraph_place_id",
                                               "date_range_start",
                                               "date_range_end"]]))

        temp_ary = DataFrame(JSON3.read(temp_json_ele))
        temp_ary = hcat(temp_id, temp_ary)

        #vertical combine;
        ary_visit_home = vcat(ary_visit_home, temp_ary, cols = :union)
        print("\r$(iter/ncount*100)%")
    end
    return ary_visit_home
end
# Parallelize above
@everywhere function sub_paralell_jsontreat(df_iter)
    try
        ary_visit_home = DataFrame(JSON3.read(df_iter));
        return Array(ary_visit_home);
    catch
        # If there is no entry
        return "no entry"
    end
end

function cbg_json_ary_paral(df, icol)
    n, k = size(df);
    @everywhere ncount = $n;
    df_sub = deepcopy(df[:, icol]);

    temp = sub_paralell_jsontreat(df_sub[1]);
    kcol = length(temp);
    @everywhere colcount = $kcol;
    # WARNING: If it is number of days, make sure to start with correct column
    ## Initialize result to save
    res_parallel = SharedArray{Float64}(ncount, colcount);
    res_parallel[:,:] .= -1;
    # Value of negative -1 is not possible,
    #       such that we can sort out failed results.

    # Go through the loop and save results
    @sync @distributed for iter = 1:ncount
        temp_res = sub_paralell_jsontreat(df_sub[iter]);
        if temp_res == "no entry"
            # If no entry - fill with missing, and go through next iteration
            # -1 for missing value
            res_parallel[iter, 1:colcount] .= -1;
            continue
        end
        temp_k = length(temp_res);
        res_parallel[iter, 1:temp_k] = temp_res;
        # Also can use fetch!() instead of @sync preamble
    end
    bool_val = sum(res_parallel .== -1) == 0; # To validate success.
    println("Parallelization computation success: $(bool_val)");
    return res_parallel;
end
#=
# NOTE: Example subroutine to run fuction
df = DataFrame(load(File(format"CSV", "patterns-part1.csv.gz")));
temp_id = deepcopy(DataFrame(df[1:ncount, ["safegraph_place_id",
                                           "date_range_start",
                                           "date_range_end"]]));
cbg_json_ary_paral(df, "popularity_by_day"); # To run function
=#

# Function to create data frame for popularity hour and bucket dwell time
function df_frame_byday_pop!(ary, temp_id)
    ary = DataFrame(Monday = ary[:,1],
                    Tuesday = ary[:,2],
                    Wednesday = ary[:,3],
                    Thursday = ary[:,4],
                    Friday = ary[:,5],
                    Saturday = ary[:,6],
                    Sunday = ary[:,7]
                    );
    ary = hcat(temp_id, ary);
    return ary;
end
#=
result = cbg_json_ary_paral(df, "popularity_by_day");
result = df_frame_byday_pop!(result, temp_id)
=#
function df_frame_bucket_dwell!(ary, temp_id)
    ary = DataFrame(less_five = ary[:,1],
                    five_20 = ary[:,2],
                    two1_1hr = ary[:,3],
                    hr1_4hr = ary[:,4],
                    hr4_greater = ary[:,5]
                    );
    ary = hcat(temp_id, ary);
    return ary;
end
#=
result = cbg_json_ary_paral(df, "bucketed_dwell_times")
df_frame_bucket_dwell!(result, temp_id)
=#
#=
# NOTE: Validation of results
df_val = DataFrame(df[1:ncount, ["safegraph_place_id", "date_range_start",
                               "date_range_end", "popularity_by_day"]])
val = innerjoin(df_val, result, on = ["safegraph_place_id", "date_range_start",
                               "date_range_end"])
val_row = deepcopy(rand(1:n, 1))[]
val[val_row,4]
val[val_row,5:end]
=#

## Function to compute popularity by hour matrix form
# Find location of interest - for after data is all compiled
function loc_find(vec, str)
        idx_loc_col = findfirst.(str, vec) .!== nothing
        count = sum(idx_loc_col)
        return idx_loc_col, count
end

# Relevant functions to create matrix of visitors by day of week
function df_parce_day_wky(vec)
        n = size(vec, 1)
        @everywhere vec
        res = SharedArray{Float64}(n, 7)
        @sync @distributed for iter ∈ 1:n
            temp = strip(vec[iter], ['[', ']'])
            res[iter, :] = Matrix(parse.(Float64, split(temp, ','))')
        end
        return res;
end

# Relevant functions to create matrix of hours by day format
function df_parce_hrs_day(vec)
        n = size(vec, 1)
        res = zeros(n, 24)
        vec = [strip(vec[iter], ['[', ']']) for iter ∈ 1:n];
        for iter ∈ 1:n
            try # to address missing values 
                res[iter, :] = Matrix(parse.(Float64, split(vec[iter], ','))')
            catch # -1 for missing value
                res[iter, :] .= -1;
            end  
        end
        res = df_frame_hrs_day(res)
        return res;
end

# Safegraph's data of hourstarts at midnight to 1 a.m. interval for local time.
function df_frame_hrs_day(ary)
        res = DataFrame(hr_01 = ary[:, 1],
                        hr_02 = ary[:, 2],
                        hr_03 = ary[:, 3],
                        hr_04 = ary[:, 4],
                        hr_05 = ary[:, 5],
                        hr_06 = ary[:, 6],
                        hr_07 = ary[:, 7],
                        hr_08 = ary[:, 8],
                        hr_09 = ary[:, 9],
                        hr_10 = ary[:, 10],
                        hr_11 = ary[:, 11],
                        hr_12 = ary[:, 12],
                        hr_13 = ary[:, 13],
                        hr_14 = ary[:, 14],
                        hr_15 = ary[:, 15],
                        hr_16 = ary[:, 16],
                        hr_17 = ary[:, 17],
                        hr_18 = ary[:, 18],
                        hr_19 = ary[:, 19],
                        hr_20 = ary[:, 20],
                        hr_21 = ary[:, 21],
                        hr_22 = ary[:, 22],
                        hr_23 = ary[:, 23],
                        hr_24 = ary[:, 24],
                        );
        return res;
end

# Relevant functions to create matrix of hours by day format, for every day of
#   each week
# NOTE: For simplicity, the Day indicator is sequencially representing Mon - Sun
#   Starting 1
function df_parce_hrs_daywky(vec, temp_id)
    n = size(vec, 1)
    @everywhere vec
    # Panel of 7 days
    res = SharedArray{Float64}(7*n, 24);
    @sync @distributed for iter ∈ 1:n
        temp = strip(vec[iter], ['[', ']']);
        temp = Matrix(parse.(Float64, split(temp, ','))');
        ind_row = (iter - 1) * 7 + 1;
        res[(ind_row:(ind_row + 6)), :] = reshape(temp, 24, :)';
    end
    res = df_frame_hrs_day(res);
    str_id = repeat(temp_id, inner = 7);
    str_days = DataFrame(ind_day = repeat(1:7, n));
    ary = hcat(str_id, str_days, res);
    return ary
end

## Processing non-uniform JSON dataformat
#NOTE: Unfortunately, was not able to find ways to parallel process the below
# JSON conversion of data format of
@everywhere function sub_paralell_jsontreat_dyn(df_iter)
    if df_iter == "{}" || df_iter == ""
        ary_name = "NA";
        ary_val = 0;
    else
        temp_ary_df = DataFrame(JSON3.read(df_iter));
        ary_name = names(temp_ary_df);
        ary_val = Array(temp_ary_df)[:];
    end
    return ary_name, ary_val;
end

# Process and tie identifier
function cbg_json_ary_dync(df, temp_id)
    iter_max = size(df,1);
    ncol = 2; # There is just value for JSON format.
    res = hcat(DataFrame(temp_id[1,:]),
               DataFrame(id_metric = "dumpsterfiernonsense", value = 1));
    res[:, "id_metric"] = convert.(Union{Missing, String}, res[:, "id_metric"])
    ncount = zeros(iter_max, 1);
    @showprogress for iter = 1:iter_max
        ary_name, ary_val = sub_paralell_jsontreat_dyn(df[iter]);
        if df[iter] == "{}" || df[iter] == ""# To account for missing data points
            temp_count = 1
        else
            temp_count = Int(size(ary_name, 1))
        end
        ncount[iter] = temp_count;
        res = append!(res,
                   hcat(repeat(DataFrame(temp_id[iter,:]), temp_count),
                        DataFrame(id_metric = ary_name, value = ary_val))
                   )
    end
    nₒ = sum(ncount);
    res = res[(res[:,4] .!= "dumpsterfiernonsense"),:];
    println("Process completion succss: $(nₒ == size(res,1))");
    return res#, sum(ncount)
end
