########################################################################
# elevateMS data release
# Purpose: To collate Daily Check-In tables in elevateMS project
#          and upload to public portal for data release
# Author: Meghasyam Tummalacherla
# email: meghasyam@sagebase.org
########################################################################
# rm(list=ls())
# gc()

##############
# Required libraries
##############
library(tidyverse)
library(data.table)
library(synapser)
library(githubr)
synapser::synLogin()

##############
# Global parameters
##############
# The target destination (where the new table is uploaded)
parent.syn.id <- 'syn21140362'
target.tbl.name <- 'Daily Check-In'
START_DATE = lubridate::ymd("2017-08-14")

##############
# Required functions
##############
source('data_curation/common_functions.R')

##############
# Download Daily Check-In tables from synapse
##############

## v1 ('syn9758010') 
## from elevateMS project
## All data except rawData column
daily.tbl.v1.syn <- synapser::synTableQuery(paste('select * from', 'syn9758010'))
all.used.ids <- 'syn9758010'
daily.tbl.v1.new <- getTableWithNewFileHandles(daily.tbl.v1.syn,
                                               parent.id = parent.syn.id,
                                               colsNotToConsider = 'rawData') 

## Get rawData from elevateMS rawData re-export project
daily.tbl.v1.rawData.syn <- synapser::synTableQuery(paste(
  'select recordId,healthCode,rawData from', 'syn21762619'))
all.used.ids <- c(all.used.ids,'syn21762619')
daily.tbl.v1.rawData.new <- getTableWithNewFileHandles(daily.tbl.v1.rawData.syn,
                                               parent.id = parent.syn.id) 


# Merge all the tables into a single one
daily.tbl.new <- daily.tbl.v1.new %>% 
  dplyr::left_join(daily.tbl.v1.rawData.new) %>% 
  unique()

# Filter based on START_DATE
daily.tbl.new <- daily.tbl.new %>% 
  dplyr::mutate(date_of_entry = as.Date(lubridate::as_datetime(createdOn))) %>% 
  dplyr::filter(date_of_entry >= START_DATE) %>% 
  dplyr::select(-date_of_entry)

# Filter/Exclude Users based on Vanessa's offline analysis
to_exclude_users <- fread(synGet("syn17870261")$path)
all.used.ids <- c(all.used.ids, 'syn17870261')
daily.tbl.new <- daily.tbl.new %>% 
  dplyr::filter(!healthCode %in% to_exclude_users$healthCode) 

# Filter based on userSharingScope
daily.tbl.new <- daily.tbl.new %>% 
  dplyr::filter(userSharingScope == 'ALL_QUALIFIED_RESEARCHERS')

# Remove dataGroups column from all tables except Baseline Characteristics
# Remove unneccessary columns
daily.tbl.new <- daily.tbl.new %>% 
  dplyr::select(-dataGroups, 
                -externalId,
                -userSharingScope,
                -validationErrors,
                -substudyMemberships,
                -dayInStudy)

##############
# Table Metadata (column names, types etc.,)
##############
# Get the reference column schema to use for the new table
cols.types <- synapser::synGetColumns('syn9758010')$asList()

# Remove the dataGroups column
cols.types <- removeColumnInSchemaColumns(cols.types, 'dataGroups')
cols.types <- removeColumnInSchemaColumns(cols.types, 'externalId')
cols.types <- removeColumnInSchemaColumns(cols.types, 'userSharingScope')
cols.types <- removeColumnInSchemaColumns(cols.types, 'validationErrors')
cols.types <- removeColumnInSchemaColumns(cols.types, 'substudyMemberships')
cols.types <- removeColumnInSchemaColumns(cols.types, 'dayInStudy')

##############
# Upload to Synapse
##############
# Github link
gtToken = 'github_token.txt';
githubr::setGithubToken(as.character(read.table(gtToken)$V1))
thisFileName <- 'data_curation/curate_dailyCheckIn.R'
thisRepo <- getRepo(repository = "itismeghasyam/elevateMS_data_release", ref="branch", refName='master')
thisFile <- getPermlink(repository = thisRepo, repositoryPath=thisFileName)

## Upload new table to Synapse
daily.tbl.syn.new <- synapser::synBuildTable(name = target.tbl.name,
                                             parent = parent.syn.id,
                                             values = daily.tbl.new)
daily.tbl.syn.new$schema <- synapser::Schema(name = target.tbl.name,
                                             columns = cols.types, # Specify column types
                                             parent = parent.syn.id)
tbl.syn.new <- synapser::synStore(daily.tbl.syn.new)
act <- synapser::Activity(name = target.tbl.name,used = all.used.ids, executed = thisFile)
synapser::synSetProvenance(tbl.syn.new, activity = act)
