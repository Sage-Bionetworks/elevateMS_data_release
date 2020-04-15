############################################################################
# elevateMS data release
# Purpose: Score WPAI Surveys
# Author: Meghasyam Tummalacherla
# email: meghasyam@sagebase.org
# NOTE: code adapted from https://github.com/Sage-Bionetworks/elevateMS_analysis/blob/master/featureExtraction/score_WPAI_surveys.R
############################################################################
rm(list=ls())
gc()

##############
# Required libraries
##############
library(synapser)
library(tidyverse)
library(githubr) 
# devtools::install_github("brian-bot/githubr")
synapser::synLogin()

##############
# Global parameters
##############
# The target destination (where the new table is uploaded)
parent.syn.id <- 'syn21140362'
target.tbl.name <- 'WPAI'
START_DATE = lubridate::ymd("2017-08-14")

##############
# Required functions
##############
source('data_curation/common_functions.R')

##############
# Download data from synapse and curate it
##############
# Version 1 of the WPAI table
wpai_synTable <- 'syn9920298'
wpai.syn <- synapser::synTableQuery(paste("select * from", wpai_synTable))
all.used.ids <- wpai_synTable
wpai1 <- getTableWithNewFileHandles(wpai.syn, parent.id = parent.syn.id,
                                    colsNotToConsider = 'rawData')

# Version 2 of the WPAI table
wpai_synTable <- 'syn10505930'
wpai.syn <- synapser::synTableQuery(paste("select * from", wpai_synTable))
all.used.ids <- c(all.used.ids, wpai_synTable)
wpai2 <- getTableWithNewFileHandles(wpai.syn, parent.id = parent.syn.id,
                                    colsNotToConsider = 'rawData')

# Merged table which we will be working on
wpai_all <- rbind(wpai1, wpai2)

# filter based on START_DATE
wpai_all <- wpai_all %>% 
  dplyr::mutate(createdOnDate = as.Date(createdOn)) %>% 
  dplyr::filter(createdOnDate >= START_DATE) %>% 
  dplyr::select(-createdOnDate)

# Filter/Exclude Users based on Vanessa's offline analysis
to_exclude_users <- fread(synGet("syn17870261")$path)
all.used.ids <- c(all.used.ids, 'syn17870261')
wpai_all <- wpai_all %>% 
  dplyr::filter(!healthCode %in% to_exclude_users$healthCode) 

# Filter/Exclude Users who withdrew from the study
withdrew_users <- fread(synGet("syn21927918")$path)
all.used.ids <- c(all.used.ids, 'syn21927918')
wpai_all <- wpai_all %>% 
  dplyr::filter(!healthCode %in% withdrew_users$healthCode) 

# filter based on userSharingScope
wpai_all <- wpai_all %>% 
  dplyr::filter(userSharingScope == 'ALL_QUALIFIED_RESEARCHERS')

# Remove dataGroups column from all tables except Baseline Characteristics
# Remove unneccessary columns
wpai_all <- wpai_all %>% 
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
cols.types <- synapser::synGetColumns('syn10505930')$asList()

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
thisFileName <- 'data_curation/curate_WPAI.R'
thisRepo <- getRepo(repository = "itismeghasyam/elevateMS_data_release", ref="branch", refName='master')
thisFile <- getPermlink(repository = thisRepo, repositoryPath=thisFileName)

## Upload new table to Synapse
wpai.syn.new <- synapser::synBuildTable(name = target.tbl.name,
                                                parent = parent.syn.id,
                                                values = wpai_all)
tbl.syn.new <- synapser::synStore(wpai.syn.new)
act <- synapser::Activity(name = target.tbl.name,used = all.used.ids, executed = thisFile)
synapser::synSetProvenance(tbl.syn.new, activity = act)

