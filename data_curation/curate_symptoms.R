########################################################################
# elevateMS data release
# Purpose: To collate Symptoms Survey tables in elevateMS project
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
target.tbl.name <- 'Symptoms Survey'
START_DATE = lubridate::ymd("2017-08-14")

##############
# Required functions
##############
source('data_curation/common_functions.R')

##############
# Download Symptoms Survey tables from synapse
##############

## v1 ('syn9765702')
symptoms.tbl.v1.syn <- synapser::synTableQuery(paste(
  'select * from', 'syn9765702'
  # , " where healthCode = 'f6bfd9d0-6558-41a7-95f8-e913d4312014'"
))
all.used.ids <- 'syn9765702'
symptoms.tbl.v1.new <- getTableWithNewFileHandles(symptoms.tbl.v1.syn,
                                                  parent.id = parent.syn.id,
                                                  colsNotToConsider = 'rawData') 

# Merge all the tables into a single one
symptoms.tbl.new <- symptoms.tbl.v1.new

# Filter based on START_DATE
symptoms.tbl.new <- symptoms.tbl.new %>% 
  dplyr::mutate(date_of_entry = as.Date(lubridate::as_datetime(metadata.json.startDate))) %>% 
  dplyr::filter(date_of_entry >= START_DATE) %>% 
  dplyr::select(-date_of_entry)

# Filter/Exclude Users based on Vanessa's offline analysis
to_exclude_users <- fread(synGet("syn17870261")$path)
all.used.ids <- c(all.used.ids, 'syn17870261')
symptoms.tbl.new <- symptoms.tbl.new %>% 
  dplyr::filter(!healthCode %in% to_exclude_users$healthCode) 

# Filter/Exclude Users who withdrew from the study
withdrew_users <- fread(synGet("syn21927918")$path)
all.used.ids <- c(all.used.ids, 'syn21927918')
symptoms.tbl.new <- symptoms.tbl.new %>% 
  dplyr::filter(!healthCode %in% withdrew_users$healthCode) 

# Filter based on userSharingScope
symptoms.tbl.new <- symptoms.tbl.new %>% 
  dplyr::filter(userSharingScope == 'ALL_QUALIFIED_RESEARCHERS')

# Remove dataGroups column from all tables except Baseline Characteristics
# Remove unneccessary columns
symptoms.tbl.new <- symptoms.tbl.new %>% 
  dplyr::select(-dataGroups, 
                -externalId,
                -userSharingScope,
                -validationErrors,
                -substudyMemberships,
                -dayInStudy)

## Get local filepaths after converting
# symptomTiming.json.choiceAnswers into a JSON
dir.create('hhh') # temp directory to hold local json files
symptoms.tbl.new <- symptoms.tbl.new %>% 
  dplyr::mutate(filePath = paste0('hhh/',recordId, '.json')) 

apply(symptoms.tbl.new, 1, function(x){
  temp.json <- jsonlite::fromJSON(x['symptomTiming.json.choiceAnswers'])
  jsonlite::write_json(temp.json, x['filePath'])
})

new.col <- lapply(symptoms.tbl.new$filePath, function(fp){
  fh <- tryCatch(synapser::synUploadFileHandle(path= as.character(fp), parent=parent.syn.id),
                 error = function(e){NULL})
  ifelse(is.null(fh),
         return(NA), # missing files handled as NAs
         return(fh$id))
}) %>% unlist()

# Replace old filehandles with new ones
symptoms.tbl.new$symptomTiming.json.choiceAnswers <- new.col
symptoms.tbl.new$filePath <- NULL

##############
# Table Metadata (column names, types etc.,)
##############
# Get the reference column schema to use for the new table
cols.types <- synapser::synGetColumns('syn9765702')$asList()

# Remove the dataGroups column
cols.types <- removeColumnInSchemaColumns(cols.types, 'dataGroups')
cols.types <- removeColumnInSchemaColumns(cols.types, 'externalId')
cols.types <- removeColumnInSchemaColumns(cols.types, 'userSharingScope')
cols.types <- removeColumnInSchemaColumns(cols.types, 'validationErrors')
cols.types <- removeColumnInSchemaColumns(cols.types, 'substudyMemberships')
cols.types <- removeColumnInSchemaColumns(cols.types, 'dayInStudy')
cols.types <- removeColumnInSchemaColumns(cols.types, 'rawData')
cols.types <- removeColumnInSchemaColumns(cols.types, 'symptomTiming.json.choiceAnswers')
##############
# Upload to Synapse
##############
# Github link
gtToken = 'github_token.txt';
githubr::setGithubToken(as.character(read.table(gtToken)$V1))
thisFileName <- 'data_curation/curate_symptoms.R'
thisRepo <- getRepo(repository = "itismeghasyam/elevateMS_data_release", ref="branch", refName='master')
thisFile <- getPermlink(repository = thisRepo, repositoryPath=thisFileName)

## Upload new table to Synapse
symptoms.tbl.syn.new <- synapser::synBuildTable(name = target.tbl.name,
                                                parent = parent.syn.id,
                                                values = symptoms.tbl.new)

# Add back the new symptomTiming.json.choiceAnswers column as a FILEHANDLEID
newSchema <- synapser::Schema(name = target.tbl.name,
                              columns = cols.types, # Specify column types
                              parent = parent.syn.id)
newCol <- synapser::Column(name = 'symptomTiming.json.choiceAnswers',
                           columnType = 'FILEHANDLEID')
newSchema$addColumn(newCol)

symptoms.tbl.syn.new$schema <- newSchema
tbl.syn.new <- synapser::synStore(symptoms.tbl.syn.new)
act <- synapser::Activity(name = target.tbl.name,used = all.used.ids, executed = thisFile)
synapser::synSetProvenance(tbl.syn.new, activity = act)

# Remove local temp directory
unlink('hhh', recursive = T)
