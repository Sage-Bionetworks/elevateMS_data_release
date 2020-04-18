########################################################################
# elevateMS data release
# Purpose: To curate Brain Baseline VSST tables in elevateMS project
#          and upload to public portal for data release
# Author: Meghasyam Tummalacherla, Abhishek Pratap
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
target.tbl.name <- 'Voice-based Digital Symbol Substitution Test'
START_DATE = lubridate::ymd("2017-08-14")

##############
# Required functions
##############
source('data_curation/common_functions.R')

##############
# Download Brain Baseline VSST utterance result table from synapse
##############
# Identifiers map
healthCode_to_externalID <- synTableQuery("select * from syn11439398")
healthCode_to_externalID <- healthCode_to_externalID$asDataFrame() %>%
  dplyr::select(externalId, healthCode)
healthCode_to_externalID <- healthCode_to_externalID[!duplicated(healthCode_to_externalID),]
all.used.ids <- 'syn11439398'

# VSST results
dsstResults <- synTableQuery("select * from syn11309241")
dsstResults <- dsstResults$asDataFrame()
dsstResults <- merge(dsstResults, healthCode_to_externalID, all.x=T)
all.used.ids <- c(all.used.ids, 'syn11309241')

# Summarize VSST results
dsst <- dsstResults %>% 
  dplyr::group_by(healthCode, blockId) %>% 
  dplyr::summarise(numDigits = n(), 
                   activityStartTime_GMT = min(createdOn),
                   numCorrect = sum(accuracy == 'y'),
                   percentCorrect = 100 * round(numCorrect/numDigits, digits=2),
                   avgTime = mean(durationMS/1000, na.rm=T),
                   sdTime = sd(durationMS/1000, na.rm=T),
                   totalTime = sum(durationMS/1000, na.rm=T)) %>% 
  dplyr::ungroup()

# Filter based on START_DATE
dsst <- dsst %>% 
  dplyr::mutate(date_of_entry = as.Date(lubridate::as_datetime(activityStartTime_GMT))) %>% 
  dplyr::filter(date_of_entry >= START_DATE) %>% 
  dplyr::select(-date_of_entry)

# Filter/Exclude Users based on Vanessa's offline analysis
to_exclude_users <- fread(synGet("syn17870261")$path)
all.used.ids <- c(all.used.ids, 'syn17870261')
dsst <- dsst %>% 
  dplyr::filter(!healthCode %in% to_exclude_users$healthCode) 

# Filter/Exclude Users who withdrew from the study
withdrew_users <- fread(synGet("syn21927918")$path)
all.used.ids <- c(all.used.ids, 'syn21927918')
dsst <- dsst %>% 
  dplyr::filter(!healthCode %in% withdrew_users$healthCode) 

# baseline characteristics for user sharing scope
baseline.char <- synTableQuery('SELECT * FROM syn21930532')
baseline.char <- baseline.char$asDataFrame()
all.used.ids <- c(all.used.ids, 'syn21930532')

# Filter based on userSharingScope - 
# retain only those healthCode present in baseline characteristics
# since it is already filtered for user sharing scope
dsst <- dsst %>% 
  dplyr::filter(healthCode %in% baseline.char$healthCode)

##############
# Upload to Synapse
##############
# Github link
gtToken = 'github_token.txt';
githubr::setGithubToken(as.character(read.table(gtToken)$V1))
thisFileName <- 'data_curation/curate_brainBaseline.R'
thisRepo <- getRepo(repository = "itismeghasyam/elevateMS_data_release", ref="branch", refName='master')
thisFile <- getPermlink(repository = thisRepo, repositoryPath=thisFileName)

## Upload new table to Synapse
dsst.syn.new <- synapser::synBuildTable(name = target.tbl.name,
                                                parent = parent.syn.id,
                                                values = dsst)
# no filehandleId type columns, so let Synapse decide column types by default
tbl.syn.new <- synapser::synStore(dsst.syn.new)
act <- synapser::Activity(name = target.tbl.name,used = all.used.ids, executed = thisFile)
synapser::synSetProvenance(tbl.syn.new, activity = act)
