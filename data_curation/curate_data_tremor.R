########################################################################
# elevateMS data release
# Purpose: To collate all tremor data tables in elevateMS project
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
target.tbl.name <- 'Tremor'
START_DATE = lubridate::ymd("2017-08-14")

##############
# Required functions
##############
source('data_curation/common_functions.R')

##############
# Download tremor tables from synapse
##############
# There are two tables in the elevateMS project

## v4 ('syn9920297')
tremor.tbl.v4.syn <- synapser::synTableQuery(paste(
  'select * from', 'syn9920297'
  # , " where healthCode = '41167e8c-f444-4a65-8689-1e3f7878d072'"
))
all.used.ids <- 'syn9920297'
tremor.tbl.v4.new <- getTableWithNewFileHandles(tremor.tbl.v4.syn
                                                 , parent.id = parent.syn.id,
                                                colsNotToConsider = 'rawData') %>% 
  dplyr::rename(ac4_acc_tremor_handToNose_right.json.items = ac4_acc_tremor_handToNose_right.json,
                ac4_motion_tremor_handToNose_right.json.items = ac4_motion_tremor_handToNose_right.json,
                ac4_acc_tremor_handToNose_left.json.items = ac4_acc_tremor_handToNose_left.json,
                ac4_motion_tremor_handToNose_left.json.items = ac4_motion_tremor_handToNose_left.json)
# renaming to confirm to v5's nomenclature

## v5 ('syn10278767')
tremor.tbl.v5.syn <- synapser::synTableQuery(paste(
  'select * from', 'syn10278767'
  # , " where healthCode = '41167e8c-f444-4a65-8689-1e3f7878d072'"
))
all.used.ids <- c(all.used.ids, 'syn10278767')
tremor.tbl.v5.new <- getTableWithNewFileHandles(tremor.tbl.v5.syn,
                                                 parent.id = parent.syn.id,
                                                colsNotToConsider = 'rawData') 

# Merge all the tables into a single one
tremor.tbl.new <- rbind(tremor.tbl.v4.new,tremor.tbl.v5.new)

# Filter based on START_DATE
tremor.tbl.new <- tremor.tbl.new %>% 
  dplyr::mutate(date_of_entry = as.Date(lubridate::as_datetime(metadata.json.startDate))) %>% 
  dplyr::filter(date_of_entry >= START_DATE) %>% 
  dplyr::select(-date_of_entry)

# Filter/Exclude Users based on Vanessa's offline analysis
to_exclude_users <- fread(synGet("syn17870261")$path)
all.used.ids <- c(all.used.ids, 'syn17870261')
tremor.tbl.new <- tremor.tbl.new %>% 
  dplyr::filter(!healthCode %in% to_exclude_users$healthCode) 

# Filter/Exclude Users who withdrew from the study
withdrew_users <- fread(synGet("syn21927918")$path)
all.used.ids <- c(all.used.ids, 'syn21927918')
tremor.tbl.new <- tremor.tbl.new %>% 
  dplyr::filter(!healthCode %in% withdrew_users$healthCode) 

# Filter based on userSharingScope
tremor.tbl.new <- tremor.tbl.new %>% 
  dplyr::filter(userSharingScope == 'ALL_QUALIFIED_RESEARCHERS')

# Remove dataGroups column from all tables except Baseline Characteristics
# Remove unneccessary columns
tremor.tbl.new <- tremor.tbl.new %>% 
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
cols.types <- synapser::synGetColumns('syn10278767')$asList()

# Remove the dataGroups column
cols.types <- removeColumnInSchemaColumns(cols.types, 'dataGroups')
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
thisFileName <- 'data_curation/curate_data_tremor.R'
thisRepo <- getRepo(repository = "Sage-Bionetworks/elevateMS_data_release", ref="branch", refName='master')
thisFile <- getPermlink(repository = thisRepo, repositoryPath=thisFileName)

## Upload new table to Synapse
tremor.tbl.syn.new <- synapser::synBuildTable(name = target.tbl.name,
                                               parent = parent.syn.id,
                                               values = tremor.tbl.new)
tremor.tbl.syn.new$schema <- synapser::Schema(name = target.tbl.name,
                                               columns = cols.types, # Specify column types
                                               parent = parent.syn.id)
tbl.syn.new <- synapser::synStore(tremor.tbl.syn.new)
act <- synapser::Activity(name = target.tbl.name,used = all.used.ids, executed = thisFile)
synapser::synSetProvenance(tbl.syn.new, activity = act)
