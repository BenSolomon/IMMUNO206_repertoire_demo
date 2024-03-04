library(dplyr)
library(tidyr)
library(purrr)
library(vroom)
library(here)
# library(R.utils)
library(readr)
library(furrr)

################################################################################
# Make miniature version of YF data from ImmuneAccess for faster demo

prop <- 0.01 # Fraction of repertoire to retain

# tibble(file = list.files(here("yf_data/"))) %>% # List all files
#   filter(grepl("^S", file)) %>% # Filter repertoire files
#   mutate(l = map_int(file, ~countLines(here(sprintf("yf_data/%s", .)))[[1]])) %>% # Count lines in each file
#   mutate(n = ceiling(l*prop)) %>% # Set desired number of sequences to retain
#   mutate(data = map2(file, n, function(f, n){
#     vroom(here(sprintf("yf_data/%s", f)), n_max = n) %>% # Read file to desired number of sequences
#       write_tsv(here(sprintf("yf_data_mini/%s.tsv.gz", f))) # Write mini file
#   }))



subsample_cdr_dataset <- function(path, prop){
  print(sprintf("# Starting sample %s", path))
  
  # Read in data
  df <- vroom(path) %>% 
    rename(count = `count (templates/reads)`)
  
  # Correct counts if 0 or negative count included in data
  if (min(df$count) <= 0){
    correction <-  1-min(df$count)
    df <- df %>% mutate(count = count + correction)
  }
  
  # Create smaller df of only unique nucleotide and count
  df_index <- df %>% select(nucleotide, count)
  
  # Subsample index to proprotion 
  n <- ceiling(sum(df_index$count)*prop)
  df_index <- df_index %>% 
    slice_sample(n = n, weight_by = count, replace = T) %>% 
    count(nucleotide, sort = T)
  
  # Rejoin index to full data
  df_index %>% 
    left_join(df, by = "nucleotide") %>% 
    mutate(`count (templates/reads)` = n) %>% 
    select(-n)
}

plan(multisession, workers = 20) # Set workers to number of desired/available threads

tibble(file = list.files(here("yf_data/"))) %>% # List all files
  filter(!grepl("^SampleOverview|^metadata", file)) %>% # Filter repertoire files
  mutate(data = future_map(file, function(f){
    df <- subsample_cdr_dataset(here(sprintf("yf_data/%s", f)), prop = prop)
    write_tsv(df, here(sprintf("yf_data_mini/%s", f))) # Write mini file
  }))

################################################################################
# Format metadata downloaded from ImmuneAccess
read_tsv(here("yf_data/SampleOverview_03-01-2024_3-45-27_PM.tsv")) %>% 
  rename(Sample = sample_name) %>% 
  separate(Sample, into = c("subject", "cell", "day"), sep = "_", remove = F) %>% 
  write_tsv(here("yf_data_mini/metadata.tsv"))
