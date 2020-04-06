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
# Scoring Function for WPAI:SHP
##############
score_wpai_shp <- function(wpai_answers){
  # Reference: http://www.reillyassociates.net/WPAI_Scoring.html
  # The input needs to be a list containing keys from Q1, Q2,...Q6
  # The output is a list of length 4
  recordId <- wpai_answers['recordId']
  Q1 <- wpai_answers['Q1']
  Q2 <- as.numeric(wpai_answers['Q2'])
  Q3 <- as.numeric(wpai_answers['Q3'])
  Q4 <- as.numeric(wpai_answers['Q4'])
  Q5 <- as.numeric(wpai_answers['Q5'])
  Q6 <- as.numeric(wpai_answers['Q6'])
  
  return(
    list(percent_work_time_missed_due_to_problem = 100*Q2/(Q2+Q4),
         percent_impairment_while_working_due_to_problem = 100*Q5/10,
         percent_overall_work_impairment_due_to_problem = 100*(Q2/(Q2+Q4)+((1-(Q2/(Q2+Q4)))*(Q5/10))),
         percent_activity_impairment_due_to_problem = 100*Q6/10,
         recordId = recordId)
  )
}

##############
# Download data from synapse and curate it
##############
# Version 1 of the WPAI table
wpai_synTable <- 'syn9920298'
wpai.syn <- synapser::synTableQuery(paste("select * from", wpai_synTable))
wpai1 <- wpai.syn$asDataFrame()
all.used.ids <- wpai_synTable

# Version 2 of the WPAI table
wpai_synTable <- 'syn10505930'
wpai.syn <- synapser::synTableQuery(paste("select * from", wpai_synTable))
wpai2 <- wpai.syn$asDataFrame()
all.used.ids <- c(all.used.ids, wpai_synTable)

# Merged table which we will be working on
wpai <- wpai2 %>%
  dplyr::full_join(wpai1)

# Rename all the required questions into format we want, i.e Q1, Q2,..Q6
# because easier for the scoring function
wpai <- wpai %>%
  dplyr::rename('Q1' = '01_employment_status',
                'Q2' = '02_missed_work_ms',
                'Q3' = '03_missed_work_holiday',
                'Q4' = '04_hours_worked',
                'Q5' = '05_work_productivity',
                'Q6' = '06_other_activities',
                'Q2_unit' = '02_missed_work_ms_unit',
                'Q3_unit' = '03_missed_work_holiday_unit',
                'Q4_unit' = '04_hours_worked_unit')

##############
# Calculate WPAI scores on the curated data
##############
wpai_scores <- apply(wpai, 1, score_wpai_shp) %>%
  data.table::rbindlist() %>% 
  as.data.frame()

wpai_all <- wpai2 %>%
  dplyr::full_join(wpai1) %>% 
  dplyr::left_join(wpai_scores)

# filter based on START_DATE
wpai_all <- wpai_all %>% 
  dplyr::mutate(createdOnDate = as.Date(createdOn)) %>% 
  dplyr::filter(createdOnDate >= START_DATE) %>% 
  dplyr::select(-createdOnDate)

# filter based on userSharingScope
wpai_all <- wpai_all %>% 
  dplyr::filter(userSharingScope == 'ALL_QUALIFIED_RESEARCHERS')

# Filter/Exclude Users based on Vanessa's offline analysis
to_exclude_users <- fread(synGet("syn17870261")$path)
all.used.ids <- c(all.used.ids, 'syn17870261')
wpai_all <- wpai_all %>% 
  dplyr::filter(!healthCode %in% to_exclude_users$healthCode) 

# Remove dataGroups column from all tables except Baseline Characteristics
# Remove unneccessary columns
wpai_all <- wpai_all %>% 
  dplyr::select(-ROW_ID,
                -ROW_VERSION,
                -dataGroups, 
                -externalId,
                -userSharingScope,
                -validationErrors,
                -substudyMemberships,
                -dayInStudy)

##############
# Upload to Synapse
##############
# Github link
gtToken = 'github_token.txt';
githubr::setGithubToken(as.character(read.table(gtToken)$V1))
thisFileName <- 'data_curation/score_WPAI_surveys.R'
thisRepo <- getRepo(repository = "itismeghasyam/elevateMS_data_release", ref="branch", refName='master')
thisFile <- getPermlink(repository = thisRepo, repositoryPath=thisFileName)

## Upload new table to Synapse
wpai.syn.new <- synapser::synBuildTable(name = target.tbl.name,
                                                parent = parent.syn.id,
                                                values = wpai_all)
# no filehandleId type columns, so let Synapse decide column types by default
synapser::synStore(wpai.syn.new, used = all.used.ids, executed = thisFile)
