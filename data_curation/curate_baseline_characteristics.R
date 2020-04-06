########################################################################
# elevateMS data release
# Purpose: To collate all baseline characteristics data tables in elevateMS project 
#          and upload to public portal
# Author: Meghasyam Tummalacherla, Abhishek Pratap
# email: meghasyam@sagebase.org
# NOTE: code adapted from https://github.com/Sage-Bionetworks/elevateMS_analysis/blob/master/featureExtraction/baselineCharacteristics.R
########################################################################
# rm(list=ls())
# gc()

##############
# Required libraries
##############
library(tidyverse)
library(data.table)
library(synapser)
library(lubridate)
library(zipcode)
library(githubr)
data(zipcode)
synapser::synLogin()

##############
# Global parameters
##############
# The target destination (where the new table is uploaded)
parent.syn.id <- 'syn21140362'
target.tbl.name <- 'Baseline Characteristics'
START_DATE = lubridate::ymd("2017-08-14")

##############
# Required functions
##############
source('data_curation/common_functions.R')

stringfy <- function(x){
  gsub('[\\[\"\\]]','',x, perl=T) 
}

tmp_select_val <- function(date_of_entry, value){
  x <- data.frame(date_of_entry=date_of_entry, value=value) %>% 
    dplyr::arrange(date_of_entry) %>%
    na.omit()
  if (nrow(x) == 0){
    return('NA')
  } else{
    return(as.character(x$value[nrow(x)]))
  }
}

##############
# Download tables from synapse and modify them
##############
## Demographics-v2 
demog.syn.id <- 'syn10295288'
all.used.ids <- 'syn10295288'
demog.syn <-  synapser::synTableQuery(paste("select * from", demog.syn.id))
demog <- demog.syn$asDataFrame() %>% 
  dplyr::select(-ROW_ID, -ROW_VERSION, # remove unneccessary columns
                -metadata.json.dataGroups, -substudyMemberships)
# update columns names
colnames(demog) <- gsub('.json.answer', '',colnames(demog))
colnames(demog)  <- gsub('metadata.json.', '',colnames(demog))
demog <- demog %>%
  dplyr::filter(dataGroups %in% c('control', 'ms_patient')) %>%
  dplyr::mutate(date_of_entry = as.Date(lubridate::as_datetime(startDate))) %>%
  dplyr::select(-scheduledActivityGuid, -endDate, -endDate.timezone, 
                -validationErrors, -startDate.timezone, -startDate, -appVersion, 
                -phoneInfo, -createdOn, -createdOnTimeZone, -recordId, -uploadDate, -rawData) %>%
  dplyr::filter(date_of_entry >= START_DATE)

# gather all race columns into a single column
raceCols <- colnames(demog)[grepl('race', colnames(demog))]
race <- demog %>% 
  tidyr::gather(race, value, raceCols) %>% 
  dplyr::filter(value == T) %>% 
  dplyr::mutate(race = gsub('race.','',race)) %>% 
  dplyr::select(healthCode, race) %>% 
  dplyr::group_by(healthCode) %>%
  dplyr::summarise(race = paste(unique(race),collapse=','))
demog <- merge(demog, race) %>% 
  dplyr::select(-raceCols, -dayInStudy)
demog <- demog %>% 
  dplyr::mutate(weight = weight/2.2) # Pounds to Kilogram 

# Fix race annotations
to_replace <- grepl('latino_hispanic', demog$race)
demog$race[to_replace] = 'latino_hispanic'
to_replace <- grepl('black_or_african', demog$race)
demog$race[to_replace] = 'Black_African'
to_replace <- grepl('caucasian', demog$race)
demog$race[to_replace] = 'caucasian'
to_replace <- grepl('asian,pacific.*', demog$race, perl=T)
demog$race[to_replace] = 'asian'
to_replace <- grepl('native_american|caribbean|middle_eastern', demog$race)
demog$race[to_replace] = 'other'

## Profile-v2 (for age and disease char)
profiles.syn.id <- 'syn10235463'
all.used.ids <- c(all.used.ids, 'syn10235463')
profiles.syn <- synapser::synTableQuery(paste("select * from", profiles.syn.id))
profiles <- profiles.syn$asDataFrame()
colnames(profiles) <- gsub('demographics.', '',colnames(profiles))
profiles <- profiles %>% 
  dplyr::select(-ROW_ID, -ROW_VERSION, -recordId, -rawData) %>%
  dplyr::mutate(race = stringfy(race),
                date_of_entry = as.Date(lubridate::as_datetime(createdOn))) %>%
  dplyr::filter(date_of_entry >= START_DATE)
demog_from_profiles <- profiles %>%
  select(healthCode, externalId, dataGroups, userSharingScope,
         gender, height, weight, zipcode, education, health_insurance, 
         employment, date_of_entry, race)

# Join demog from two sources
demog = rbind(demog, demog_from_profiles %>%
                dplyr::select(colnames(demog))) %>%
  dplyr::mutate(height = round(height, digits=1),
                weight = round(weight, digits=1)) %>%
  dplyr::mutate_at(.funs = c(tolower),
                   .vars = c('healthCode', 'externalId', 'dataGroups', 'userSharingScope',
                             'gender','zipcode', 'education', 'race',
                             'health_insurance', 'employment', 'date_of_entry') ) %>%
  dplyr::distinct(healthCode, externalId, dataGroups, userSharingScope,
                  gender, height, weight, zipcode, education,
                  health_insurance, employment, race, .keep_all=T) 

demog_long <- demog %>% 
  tidyr::gather(feature, value,-healthCode, -date_of_entry)

## For Quality Control    
demog_summary <- demog_long %>% 
  dplyr::group_by(healthCode, feature) %>% 
  dplyr::summarise(n_uniq_values = length(unique(na.omit(value))),
                   unique_values = paste(unique(na.omit(value)), collapse=","),
                   value = tmp_select_val(date_of_entry, value))

## External ID's
externalIds <- fread(synGet("syn17057743")$path) %>%
  dplyr::mutate(id = gsub('-','', id)) %>%
  dplyr::rename(externalId = id) 
true_externalIds = unique(externalIds$externalId)
all.used.ids <- c(all.used.ids, 'syn17057743')

## Final Demog Summary
demog_clean <- demog_summary %>% 
  dplyr::select(-n_uniq_values, -unique_values) %>% 
  tidyr::spread(feature, value) %>%
  dplyr::mutate(referred_by_clinician = ifelse(externalId %in% true_externalIds , T, F)) %>%
  dplyr::filter(dataGroups %in% c('ms_patient', 'control'))

#### How many times people change their responses
# demog_changes <- demog_summary %>% select(-value) %>% spread(feature, n_uniq_values)

## Get the disease characteristics from profile
diseaseCharacteristics <- profiles %>%
  dplyr::select(healthCode, initialDiagnosis, initialDiagnosisYear, currentDiagnosis, 
                date_of_entry, currentDiagnosisYear, currentDMT, firstDMTYear, msFamilyHistory,
                overallPhysicalAbility) %>%
  dplyr::mutate_all(.funs = (tolower))  %>%
  dplyr::distinct(healthCode, initialDiagnosis, initialDiagnosisYear, currentDiagnosis, 
                  currentDiagnosisYear, currentDMT, firstDMTYear, msFamilyHistory,
                  overallPhysicalAbility, .keep_all = T)

# delete initialDiagnosis & initialDiagnosisYear
diseaseChar_summary <- diseaseCharacteristics %>%
  dplyr::select(-initialDiagnosis, -initialDiagnosisYear) %>% 
  tidyr::gather(feature, value, -healthCode, -date_of_entry) %>% 
  dplyr::group_by(healthCode, feature) %>% 
  dplyr::summarise(n_uniq_values = length(unique(na.omit(value))),
                   unique_values = paste(unique(na.omit(value)), collapse=","),
                   value = tmp_select_val(date_of_entry, value))

## Final Disease Char Summary
diseaseChar_clean <- diseaseChar_summary %>% 
  dplyr::select(-n_uniq_values, -unique_values) %>% 
  tidyr::spread(feature, value)

## Overall baseline chars
# nrow(diseaseChar_clean)
baselineChar <- merge(demog_clean, diseaseChar_clean, all=T)

## Add the Age from profiles
participant_age <- profiles %>% 
  dplyr::select(healthCode, date_of_entry, age) %>%
  dplyr::filter(!is.na(age)) %>% 
  dplyr::distinct() %>%
  dplyr::group_by(healthCode) %>% 
  dplyr::arrange(date_of_entry) %>% 
  dplyr::summarise(date_of_entry = tail(date_of_entry, n=1),
                   age = tail(age,n=1)) %>%
  dplyr::select(-date_of_entry)
baselineChar <- merge(baselineChar, participant_age, all=T)

## Fix Education
to_replace <- baselineChar$education %in% c('some_high_school', 'high_school_diploma_ged')
baselineChar$education[to_replace] = 'high_school_diploma_ged'
to_replace <- baselineChar$education %in% c('some_college')
baselineChar$education[to_replace] = 'college_degree'

# make height and weight numeric columns
baselineChar <- baselineChar %>%
  dplyr::mutate(height = as.numeric(height),
                weight = as.numeric(weight))

## Exclude Users based on Vanessa's offline analysis
to_exclude_users <- fread(synGet("syn17870261")$path)
all.used.ids <- c(all.used.ids, 'syn17870261')
baselineChar <- baselineChar %>% 
  dplyr::filter(! healthCode %in% to_exclude_users$healthCode) 

## Fixing errors and 'NA' to NA
baselineChar['error'] = NA
baselineChar[baselineChar == 'NA'] = NA

baselineChar <- baselineChar %>% 
  dplyr::mutate( error = case_when(
    
    #1. dataGroups = NA but other MS parameters currentDiagnosis & currentDiagnosisYear indicate MS patient
    (is.na(dataGroups) | dataGroups == '')  & 
      (!is.na(currentDiagnosis) & !is.na(currentDiagnosisYear))  ~ 'Ignore|dataGroups = NA and some MS related params',
    
    #2. dataGroups = NA but other MS parameters indicate currentDMT & firstDMTYear indicate MS patient
    (is.na(dataGroups) | dataGroups == '')  & 
      (!is.na(currentDMT) & !is.na(firstDMTYear))  ~ 'Ignore|dataGroups = NA and some MS related params',
    
    
    #3. dataGroups = NA but other > 3 parameters indicate MS Params
    (dataGroups == 'control')  & 
      ( !is.na(currentDMT) | ! currentDiagnosis %in% c('no', 'notsure') | 
          !is.na(currentDiagnosisYear) | !is.na(overallPhysicalAbility))  ~ 'Ignore|dataGroups = control and some MS related params',
    
    #4. dataGroups = Control but other MS parameters indicate currentDMT & firstDMTYear indicate MS patient
    (dataGroups == 'control')  &  (referred_by_clinician == T | !is.na(externalId))  ~ 'dataGroups = control and referred_by_clinician =T', 
    
    (is.na(dataGroups) | dataGroups == '') ~ 'Ignore|dataGroups = NA'
    
  ))

baselineChar <- baselineChar %>% 
  dplyr::mutate(dataGroups = case_when(
    error == 'Ignore|dataGroups = control and some MS related params'   ~ 'Ignore',
    error == 'Ignore|dataGroups = NA and some MS related params'    ~ 'Ignore',
    error == 'Ignore|dataGroups = NA'                                      ~  'Ignore',
    error == 'dataGroups = control and referred_by_clinician =T'  ~ 'ms_patient',
    TRUE ~ .$dataGroups
  )) 

baselineChar <- baselineChar %>% 
  dplyr::mutate(YearsSinceDiagnosis =  as.numeric(lubridate::year(Sys.Date())) - as.numeric(currentDiagnosisYear),
                YearsSinceFirstDMT = as.numeric(lubridate::year(Sys.Date())) - as.numeric(firstDMTYear))

baselineChar <- baselineChar %>% 
  dplyr::mutate(health_insurance = case_when(
    health_insurance %in% c('government insurance', 'medicare', 'medicaid') ~ 'government insurance',
    health_insurance %in% c('other', 'rather not say') ~ 'other',
    TRUE ~ .$health_insurance
  )) 

baselineChar <- baselineChar %>% 
  dplyr::mutate(group = case_when(
    referred_by_clinician == T & dataGroups == 'ms_patient' ~ 'MS patients(clinical referral)',
    referred_by_clinician == F & dataGroups == 'ms_patient' ~ 'MS patients',
    dataGroups == 'control' ~ 'Controls'
  )) 

## Add State based on ZipCode
# load the zipcode level data summarized by first three digits of zipcode
states = data.frame(state = state.abb, state.name = state.name)
tmp_zipcode <- zipcode %>% 
  dplyr::inner_join(states)
tmp_zipcode['zipcode_firstThree'] = substr(tmp_zipcode$zip, 1,3)
tmp_zipcode <- tmp_zipcode %>%  
  dplyr::select(state, state.name, zipcode_firstThree) %>% 
  dplyr::distinct() %>%
  dplyr::rename(state.abbr = state, state = state.name)

# zipcodes whoose first three numbers are common across states - select first state
tmp_zipcode <- tmp_zipcode %>% 
  dplyr::group_by(zipcode_firstThree) %>% 
  dplyr::summarise(state = state[1],
                   state.abbr = state.abbr[1])

# create the new col to match to tmp_zipcode
baselineChar['zipcode_firstThree'] = substr(baselineChar$zipcode, 1,3)
baselineChar <- merge(baselineChar, tmp_zipcode, all.x = T)

# replace zipcode with first three numbers
baselineChar$zipcode <- baselineChar$zipcode_firstThree

# filter based on userSharingScope
baselineChar <- baselineChar %>% 
  dplyr::filter(userSharingScope == 'all_qualified_researchers')

# remove unneccessary columns
baselineChar <- baselineChar %>% 
  dplyr::select(-zipcode_firstThree,
                -externalId,
                -userSharingScope,
                -error,
                -state.abbr,
                -group)

##############
# Upload to Synapse
##############
# Github link
gtToken = 'github_token.txt';
githubr::setGithubToken(as.character(read.table(gtToken)$V1))
thisFileName <- 'data_curation/curate_baseline_characteristics.R'
thisRepo <- getRepo(repository = "itismeghasyam/elevateMS_data_release", ref="branch", refName='master')
thisFile <- getPermlink(repository = thisRepo, repositoryPath=thisFileName)

## Upload new table to Synapse
baselineChar.syn.new <- synapser::synBuildTable(name = target.tbl.name,
                                               parent = parent.syn.id,
                                               values = baselineChar)
# no filehandleId type columns, so let Synapse decide column types by default
tbl.syn.new <- synapser::synStore(baselineChar.syn.new)
act <- synapser::Activity(name = target.tbl.name,used = all.used.ids, executed = thisFile)
synapser::synSetProvenance(tbl.syn.new, activity = act)
