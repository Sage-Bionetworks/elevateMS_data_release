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

# Filter/Exclude Users who withdrew from the study
withdrew_users <- fread(synGet("syn21927918")$path)
all.used.ids <- c(all.used.ids, 'syn21927918')
msis.tbl.new <- msis.tbl.new %>% 
  dplyr::filter(!healthCode %in% withdrew_users$healthCode) 

# Filter based on userSharingScope
msis.tbl.new <- msis.tbl.new %>% 
  dplyr::filter(userSharingScope == 'ALL_QUALIFIED_RESEARCHERS')

# Remove dataGroups column from all tables except Baseline Characteristics
# Remove unneccessary columns by selecting only the relevant columns;
# and rename 29_confidence to 29_depression
msis.tbl.new <- msis.tbl.new %>% 
  dplyr::select(recordId,
                appVersion,
                phoneInfo,
                uploadDate,
                healthCode,
                createdOn,
                createdOnTimeZone,
                `01_demanding_tasks`,
                `02_grip`,
                `03_carry_things`,
                `04_balance`,
                `29_depression` = `29_confidence`)

##############
# Upload to Synapse
##############
# Github link
gtToken = 'github_token.txt';
githubr::setGithubToken(as.character(read.table(gtToken)$V1))
thisFileName <- 'data_curation/curate_MSIS29.R'
thisRepo <- getRepo(repository = "Sage-Bionetworks/elevateMS_data_release", ref="branch", refName='master')
thisFile <- getPermlink(repository = thisRepo, repositoryPath=thisFileName)

## Upload new table to Synapse
msis.tbl.syn.new <- synapser::synBuildTable(name = target.tbl.name,
                                            parent = parent.syn.id,
                                            values = msis.tbl.new)
# no filehandleId type columns, so let Synapse decide column types by default
tbl.syn.new <- synapser::synStore(msis.tbl.syn.new)
act <- synapser::Activity(name = target.tbl.name,used = all.used.ids, executed = thisFile)
synapser::synSetProvenance(tbl.syn.new, activity = act)
