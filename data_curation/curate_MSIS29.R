########################################################################
# elevateMS data release
# Purpose: To collate MSIS-29 tables in elevateMS project
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
target.tbl.name <- 'Truncated MSIS-29'
START_DATE = lubridate::ymd("2017-08-14")

##############
# Required functions
##############
source('data_curation/common_functions.R')

##############
# Download MSIS-29 tables from synapse
##############

## v1 ('syn9920302')
msis.tbl.v1.syn <- synapser::synTableQuery(paste(
  'select * from', 'syn9920302'
  # , " where healthCode = 'f6bfd9d0-6558-41a7-95f8-e913d4312014'"
))
all.used.ids <- 'syn9920302'
msis.tbl.v1.new <- getTableWithNewFileHandles(msis.tbl.v1.syn,
                                              parent.id = parent.syn.id,
                                              colsNotToConsider = 'rawData' ) 

# Merge all the tables into a single one
msis.tbl.new <- msis.tbl.v1.new

# Filter based on START_DATE
msis.tbl.new <- msis.tbl.new %>% 
  dplyr::mutate(date_of_entry = as.Date(lubridate::as_datetime(createdOn))) %>% 
  dplyr::filter(date_of_entry >= START_DATE) %>% 
  dplyr::select(-date_of_entry)

# Filter/Exclude Users based on Vanessa's offline analysis
to_exclude_users <- fread(synGet("syn17870261")$path)
all.used.ids <- c(all.used.ids, 'syn17870261')
msis.tbl.new <- msis.tbl.new %>% 
  dplyr::filter(!healthCode %in% to_exclude_users$healthCode) 

# Filter based on userSharingScope
msis.tbl.new <- msis.tbl.new %>% 
  dplyr::filter(userSharingScope == 'ALL_QUALIFIED_RESEARCHERS')

# Remove dataGroups column from all tables except Baseline Characteristics
# Remove unneccessary columns
msis.tbl.new <- msis.tbl.new %>% 
  dplyr::select(-dataGroups, 
                -externalId,
                -userSharingScope,
                -validationErrors,
                -substudyMemberships,
                -dayInStudy,
                -`05_difficulty_moving`, -`06_clumsy`, -`07_stiffness`,
                -`08_heavy_limbs`, -`09_tremor`, -`10_spasms`,
                -`11_body`, -`12_depend_on_others`, -`13_social_limitations`,
                -`14_stuck_at_home`, -`15_difficulty_hands`, -`16_time_spent`,
                -`17_transportation`, -`18_taking_longer`, -`19_spontaneous`,
                -`20_toilet`, -`21_feeling_unwell`, -`22_sleep`,
                -`23_mental_fatigue`, -`24_ms_worries`, -`25_feeling_anxious`,
                -`26_feeling_irritable`, -`27_concentration`, -`28_confidence`)

##############
# Table Metadata (column names, types etc.,)
##############
# Get the reference column schema to use for the new table
cols.types <- synapser::synGetColumns('syn9920302')$asList()

# Remove the dataGroups column
cols.types <- removeColumnInSchemaColumns(cols.types, 'dataGroups')
cols.types <- removeColumnInSchemaColumns(cols.types, 'externalId')
cols.types <- removeColumnInSchemaColumns(cols.types, 'userSharingScope')
cols.types <- removeColumnInSchemaColumns(cols.types, 'validationErrors')
cols.types <- removeColumnInSchemaColumns(cols.types, 'substudyMemberships')
cols.types <- removeColumnInSchemaColumns(cols.types, 'dayInStudy')
cols.types <- removeColumnInSchemaColumns(cols.types, 'rawData')
cols.types <- removeColumnInSchemaColumns(cols.types, '05_difficulty_moving')
cols.types <- removeColumnInSchemaColumns(cols.types, '06_clumsy')
cols.types <- removeColumnInSchemaColumns(cols.types, '07_stiffness')
cols.types <- removeColumnInSchemaColumns(cols.types, '08_heavy_limbs')
cols.types <- removeColumnInSchemaColumns(cols.types, '09_tremor')
cols.types <- removeColumnInSchemaColumns(cols.types, '10_spasms')
cols.types <- removeColumnInSchemaColumns(cols.types, '11_body')
cols.types <- removeColumnInSchemaColumns(cols.types, '12_depend_on_others')
cols.types <- removeColumnInSchemaColumns(cols.types, '13_social_limitations')
cols.types <- removeColumnInSchemaColumns(cols.types, '14_stuck_at_home')
cols.types <- removeColumnInSchemaColumns(cols.types, '15_difficulty_hands')
cols.types <- removeColumnInSchemaColumns(cols.types, '16_time_spent')
cols.types <- removeColumnInSchemaColumns(cols.types, '17_transportation')
cols.types <- removeColumnInSchemaColumns(cols.types, '18_taking_longer')
cols.types <- removeColumnInSchemaColumns(cols.types, '19_spontaneous')
cols.types <- removeColumnInSchemaColumns(cols.types, '20_toilet')
cols.types <- removeColumnInSchemaColumns(cols.types, '21_feeling_unwell')
cols.types <- removeColumnInSchemaColumns(cols.types, '22_sleep')
cols.types <- removeColumnInSchemaColumns(cols.types, '23_mental_fatigue')
cols.types <- removeColumnInSchemaColumns(cols.types, '24_ms_worries')
cols.types <- removeColumnInSchemaColumns(cols.types, '25_feeling_anxious')
cols.types <- removeColumnInSchemaColumns(cols.types, '26_feeling_irritable')
cols.types <- removeColumnInSchemaColumns(cols.types, '27_concentration')
cols.types <- removeColumnInSchemaColumns(cols.types, '28_confidence')

##############
# Upload to Synapse
##############
# Github link
gtToken = 'github_token.txt';
githubr::setGithubToken(as.character(read.table(gtToken)$V1))
thisFileName <- 'data_curation/curate_MSIS29.R'
thisRepo <- getRepo(repository = "itismeghasyam/elevateMS_data_release", ref="branch", refName='master')
thisFile <- getPermlink(repository = thisRepo, repositoryPath=thisFileName)

## Upload new table to Synapse
msis.tbl.syn.new <- synapser::synBuildTable(name = target.tbl.name,
                                            parent = parent.syn.id,
                                            values = msis.tbl.new)
msis.tbl.syn.new$schema <- synapser::Schema(name = target.tbl.name,
                                            columns = cols.types, # Specify column types
                                            parent = parent.syn.id)
tbl.syn.new <- synapser::synStore(msis.tbl.syn.new)
act <- synapser::Activity(name = target.tbl.name,used = all.used.ids, executed = thisFile)
synapser::synSetProvenance(tbl.syn.new, activity = act)
