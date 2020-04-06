########################################################################
# elevateMS data release
# Purpose: To collate NeuroQOL UpperExtremity in elevateMS project
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
target.tbl.name <- 'NeuroQOL-UpperExtremity'
START_DATE = lubridate::ymd("2017-08-14")

##############
# Required functions
##############
source('data_curation/common_functions.R')

##############
# Download NeuroQOL UpperExtremity table from synapse
##############

## v1 ('syn10139320')
neuroUpper.tbl.v1.syn <- synapser::synTableQuery(paste(
  'select * from', 'syn10139320'
  # , " where healthCode = 'f6bfd9d0-6558-41a7-95f8-e913d4312014'"
))
all.used.ids <- 'syn10139320'
neuroUpper.tbl.v1.new <- getTableWithNewFileHandles(neuroUpper.tbl.v1.syn,
                                                    parent.id = parent.syn.id) 

# Merge all the tables into a single one
neuroUpper.tbl.new <- neuroUpper.tbl.v1.new

# Filter based on START_DATE
neuroUpper.tbl.new <- neuroUpper.tbl.new %>% 
  dplyr::mutate(date_of_entry = as.Date(lubridate::as_datetime(createdOn))) %>% 
  dplyr::filter(date_of_entry >= START_DATE) %>% 
  dplyr::select(-date_of_entry)

# Filter/Exclude Users based on Vanessa's offline analysis
to_exclude_users <- fread(synGet("syn17870261")$path)
all.used.ids <- c(all.used.ids, 'syn17870261')
neuroUpper.tbl.new <- neuroUpper.tbl.new %>% 
  dplyr::filter(!healthCode %in% to_exclude_users$healthCode) 

# Filter based on userSharingScope
neuroUpper.tbl.new <- neuroUpper.tbl.new %>% 
  dplyr::filter(userSharingScope == 'ALL_QUALIFIED_RESEARCHERS')

# Remove dataGroups column from all tables except Baseline Characteristics
# Remove unneccessary columns
neuroUpper.tbl.new <- neuroUpper.tbl.new %>% 
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
cols.types <- synapser::synGetColumns('syn10139320')$asList()

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
thisFileName <- 'data_curation/curate_neuroQoL_upperExtremity.R'
thisRepo <- getRepo(repository = "itismeghasyam/elevateMS_data_release", ref="branch", refName='master')
thisFile <- getPermlink(repository = thisRepo, repositoryPath=thisFileName)

## Upload new table to Synapse
neuroUpper.tbl.syn.new <- synapser::synBuildTable(name = target.tbl.name,
                                                  parent = parent.syn.id,
                                                  values = neuroUpper.tbl.new)
neuroUpper.tbl.syn.new$schema <- synapser::Schema(name = target.tbl.name,
                                                  columns = cols.types, # Specify column types
                                                  parent = parent.syn.id)
tbl.syn.new <- synapser::synStore(neuroUpper.tbl.syn.new)
act <- synapser::Activity(name = target.tbl.name,used = all.used.ids, executed = thisFile)
synapser::synSetProvenance(tbl.syn.new, activity = act)
