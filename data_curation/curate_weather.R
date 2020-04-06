########################################################################
# elevateMS data release
# Purpose: To collate all weather tables in elevateMS project
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
target.tbl.name <- 'Weather'
START_DATE = lubridate::ymd("2017-08-14")

##############
# Required functions
##############
source('data_curation/common_functions.R')

##############
# Download weather tables from synapse
##############
# There are two tables in the elevateMS project

## v1 ('syn10352369')
# weather.tbl.v1.syn <- synapser::synTableQuery(paste(
#   'select * from', 'syn10352369'
#   # , " where healthCode = '41167e8c-f444-4a65-8689-1e3f7878d072'"
# ))
all.used.ids <- 'syn10352369'
# weather.tbl.v1.new <- getTableWithNewFileHandles(weather.tbl.v1.syn
#                                                 , parent.id = parent.syn.id) 
#*******NOTE*******#
# The reason weather-v1 is commented out/not considered is because
# v1 has one row (one observation) whose userSharingScope is 
# SPONSORS_AND_PARTNERS - will be filtered out anyways
#******************#


## v3 ('syn11171602')
weather.tbl.v3.syn <- synapser::synTableQuery(paste(
  'select * from', 'syn11171602'
  , " where healthCode = 'f6bfd9d0-6558-41a7-95f8-e913d4312014'"
))
all.used.ids <- c(all.used.ids, 'syn11171602')
weather.tbl.v3.new <- getTableWithNewFileHandles(weather.tbl.v3.syn,
                                                parent.id = parent.syn.id) 

# Merge all the tables into a single one
weather.tbl.new <- weather.tbl.v3.new

# Filter based on START_DATE
weather.tbl.new <- weather.tbl.new %>% 
  dplyr::mutate(date_of_entry = as.Date(lubridate::as_datetime(metadata.json.startDate))) %>% 
  dplyr::filter(date_of_entry >= START_DATE) %>% 
  dplyr::select(-date_of_entry)

# Filter/Exclude Users based on Vanessa's offline analysis
to_exclude_users <- fread(synGet("syn17870261")$path)
all.used.ids <- c(all.used.ids, 'syn17870261')
weather.tbl.new <- weather.tbl.new %>% 
  dplyr::filter(!healthCode %in% to_exclude_users$healthCode) 

# Filter based on userSharingScope
weather.tbl.new <- weather.tbl.new %>% 
  dplyr::filter(userSharingScope == 'ALL_QUALIFIED_RESEARCHERS')

# Remove dataGroups column from all tables except Baseline Characteristics
# Remove unneccessary columns
weather.tbl.new <- weather.tbl.new %>% 
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
cols.types <- synapser::synGetColumns('syn11171602')$asList()

# Remove the dataGroups column
cols.types <- removeColumnInSchemaColumns(cols.types, 'dataGroups')
cols.types <- removeColumnInSchemaColumns(cols.types, 'metadata.json.dataGroups')
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
thisFileName <- 'data_curation/curate_data_weather.R'
thisRepo <- getRepo(repository = "itismeghasyam/elevateMS_data_release", ref="branch", refName='master')
thisFile <- getPermlink(repository = thisRepo, repositoryPath=thisFileName)

## Upload new table to Synapse
# weather.tbl.syn.new <- synapser::synBuildTable(name = target.tbl.name,
#                                               parent = parent.syn.id,
#                                               values = weather.tbl.new)
# weather.tbl.syn.new$schema <- synapser::Schema(name = target.tbl.name,
#                                               columns = cols.types, # Specify column types
#                                               parent = parent.syn.id)
# synapser::synStore(weather.tbl.syn.new, used = all.used.ids, executed = thisFile)
