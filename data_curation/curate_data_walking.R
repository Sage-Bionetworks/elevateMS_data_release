########################################################################
# elevateMS data release
# Purpose: To collate all walking data tables in elevateMS project
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
target.tbl.name <- 'Walking'
START_DATE = lubridate::ymd("2017-08-14")

##############
# Required functions
##############
source('data_curation/common_functions.R')

##############
# Download walking tables from synapse
##############
# There are two tables in the elevateMS project

## v1 ('syn9934066')
walking.tbl.v1.syn <- synapser::synTableQuery(paste(
  'select * from', 'syn9934066'
  # , " where healthCode = '41167e8c-f444-4a65-8689-1e3f7878d072'"
))
all.used.ids <- 'syn9934066'
walking.tbl.v1.new <- getTableWithNewFileHandles(walking.tbl.v1.syn
                                                 , parent.id = parent.syn.id,
                                                 colsNotToConsider = 'rawData') %>% 
  dplyr::rename(accelerometer_walking_outbound.json.items = accelerometer_walking_outbound.json,
                deviceMotion_walking_outbound.json.items = deviceMotion_walking_outbound.json,
                pedometer_walking_outbound.json.items = pedometer_walking_outbound.json,
                accelerometer_walking_rest.json.items = accelerometer_walking_rest.json,
                deviceMotion_walking_rest.json.items = deviceMotion_walking_rest.json)
# renaming to confirm to v2's nomenclature

## v2 ('syn10278766')
walking.tbl.v2.syn <- synapser::synTableQuery(paste(
  'select * from', 'syn10278766'
  # , " where healthCode = '41167e8c-f444-4a65-8689-1e3f7878d072'"
))
all.used.ids <- c(all.used.ids, 'syn10278766')
walking.tbl.v2.new <- getTableWithNewFileHandles(walking.tbl.v2.syn,
                                                 parent.id = parent.syn.id,
                                                 colsNotToConsider = 'rawData') 

# Merge all the tables into a single one
walking.tbl.new <- rbind(walking.tbl.v1.new,walking.tbl.v2.new)

# Filter based on START_DATE
walking.tbl.new <- walking.tbl.new %>% 
  dplyr::mutate(date_of_entry = as.Date(lubridate::as_datetime(metadata.json.startDate))) %>% 
  dplyr::filter(date_of_entry >= START_DATE) %>% 
  dplyr::select(-date_of_entry)

# Filter/Exclude Users based on Vanessa's offline analysis
to_exclude_users <- fread(synGet("syn17870261")$path)
all.used.ids <- c(all.used.ids, 'syn17870261')
walking.tbl.new <- walking.tbl.new %>% 
  dplyr::filter(!healthCode %in% to_exclude_users$healthCode) 

# Filter/Exclude Users who withdrew from the study
withdrew_users <- fread(synGet("syn21927918")$path)
all.used.ids <- c(all.used.ids, 'syn21927918')
walking.tbl.new <- walking.tbl.new %>% 
  dplyr::filter(!healthCode %in% withdrew_users$healthCode) 

# Filter based on userSharingScope
walking.tbl.new <- walking.tbl.new %>% 
  dplyr::filter(userSharingScope == 'ALL_QUALIFIED_RESEARCHERS')

# Remove dataGroups column from all tables except Baseline Characteristics
# Remove unneccessary columns
walking.tbl.new <- walking.tbl.new %>% 
  dplyr::select(-dataGroups, 
                -metadata.json.dataGroups,
                -externalId,
                -userSharingScope,
                -validationErrors,
                -substudyMemberships,
                -dayInStudy)

##############
# Table Metadata (column names, types etc.,)
##############
# Get the reference column schema to use for the new table
cols.types <- synapser::synGetColumns('syn10278766')$asList()

# Remove the dataGroups column
cols.types <- removeColumnInSchemaColumns(cols.types, 'dataGroups')
cols.types <- removeColumnInSchemaColumns(cols.types, 'metadata.json.dataGroups')
cols.types <- removeColumnInSchemaColumns(cols.types, 'externalId')
cols.types <- removeColumnInSchemaColumns(cols.types, 'userSharingScope')
cols.types <- removeColumnInSchemaColumns(cols.types, 'validationErrors')
cols.types <- removeColumnInSchemaColumns(cols.types, 'substudyMemberships')
cols.types <- removeColumnInSchemaColumns(cols.types, 'dayInStudy')
cols.types <- removeColumnInSchemaColumns(cols.types, 'rawData')

##############
# Upload to Synapse
##############
# Github link
gtToken = 'github_token.txt';
githubr::setGithubToken(as.character(read.table(gtToken)$V1))
thisFileName <- 'data_curation/curate_data_walking.R'
thisRepo <- getRepo(repository = "itismeghasyam/elevateMS_data_release", ref="branch", refName='master')
thisFile <- getPermlink(repository = thisRepo, repositoryPath=thisFileName)

## Upload new table to Synapse
walking.tbl.syn.new <- synapser::synBuildTable(name = target.tbl.name,
                                               parent = parent.syn.id,
                                               values = walking.tbl.new)
walking.tbl.syn.new$schema <- synapser::Schema(name = target.tbl.name,
                                               columns = cols.types, # Specify column types
                                               parent = parent.syn.id)
tbl.syn.new <- synapser::synStore(walking.tbl.syn.new)
act <- synapser::Activity(name = target.tbl.name,used = all.used.ids, executed = thisFile)
synapser::synSetProvenance(tbl.syn.new, activity = act)
