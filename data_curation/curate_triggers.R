########################################################################
# elevateMS data release
# Purpose: To collate all triggers survey tables in elevateMS project
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
target.tbl.name <- 'Triggers Survey'
START_DATE = lubridate::ymd("2017-08-14")

##############
# Required functions
##############
source('data_curation/common_functions.R')

##############
# Download triggers surveys tables from synapse
##############
# There are two tables in the elevateMS project

#******************************************************#
# ## v1 ('syn10002837')
# triggers.tbl.v1.syn <- synapser::synTableQuery(paste(
#   'select * from', 'syn10002837'
#   # , " where healthCode = '41167e8c-f444-4a65-8689-1e3f7878d072'"
# ))
# all.used.ids <- 'syn10002837'
# triggers.tbl.v1.new <- getTableWithNewFileHandles(triggers.tbl.v1.syn
#                                                  , parent.id = parent.syn.id)
#***** WE ARE NOT USING V1 DATA FOR TRIGGERS***********#

## v3 ('syn10232189')
triggers.tbl.v3.syn <- synapser::synTableQuery(paste(
  'select * from', 'syn10232189'
  # , " where healthCode = '41167e8c-f444-4a65-8689-1e3f7878d072'"
))
all.used.ids <- 'syn10232189'
triggers.tbl.v3.new <- getTableWithNewFileHandles(triggers.tbl.v3.syn,
                                                 parent.id = parent.syn.id,
                                                 colsNotToConsider = 'rawData') 

# Merge all the tables into a single one
triggers.tbl.new <- triggers.tbl.v3.new

# Filter based on START_DATE
triggers.tbl.new <- triggers.tbl.new %>% 
  dplyr::mutate(date_of_entry = as.Date(lubridate::as_datetime(metadata.json.startDate))) %>% 
  dplyr::filter(date_of_entry >= START_DATE) %>% 
  dplyr::select(-date_of_entry)

# Filter/Exclude Users based on Vanessa's offline analysis
to_exclude_users <- fread(synGet("syn17870261")$path)
all.used.ids <- c(all.used.ids, 'syn17870261')
triggers.tbl.new <- triggers.tbl.new %>% 
  dplyr::filter(!healthCode %in% to_exclude_users$healthCode) 

# Filter/Exclude Users who withdrew from the study
withdrew_users <- fread(synGet("syn21927918")$path)
all.used.ids <- c(all.used.ids, 'syn21927918')
triggers.tbl.new <- triggers.tbl.new %>% 
  dplyr::filter(!healthCode %in% withdrew_users$healthCode) 

# Filter based on userSharingScope
triggers.tbl.new <- triggers.tbl.new %>% 
  dplyr::filter(userSharingScope == 'ALL_QUALIFIED_RESEARCHERS')

# Remove dataGroups column from all tables except Baseline Characteristics
# Remove unneccessary columns
triggers.tbl.new <- triggers.tbl.new %>% 
  dplyr::select(-dataGroups, 
                -externalId,
                -userSharingScope,
                -validationErrors,
                -substudyMemberships,
                -dayInStudy)

## Get local filepaths after converting
# myTriggers.json.choiceAnswers into a JSON
dir.create('hhh') # temp directory to hold local json files
triggers.tbl.new <- triggers.tbl.new %>% 
  dplyr::mutate(filePath = paste0('hhh/',recordId, '.json')) 

apply(triggers.tbl.new, 1, function(x){
  temp.json <- jsonlite::fromJSON(x['myTriggers.json.choiceAnswers'])
  jsonlite::write_json(temp.json, x['filePath'])
})

new.col <- lapply(triggers.tbl.new$filePath, function(fp){
  fh <- tryCatch(synapser::synUploadFileHandle(path= as.character(fp), parent=parent.syn.id),
                 error = function(e){NULL})
  ifelse(is.null(fh),
         return(NA), # missing files handled as NAs
         return(fh$id))
}) %>% unlist()

# Replace old filehandles with new ones
triggers.tbl.new$myTriggers.json.choiceAnswers <- new.col
triggers.tbl.new$filePath <- NULL

##############
# Table Metadata (column names, types etc.,)
##############
# Get the reference column schema to use for the new table
cols.types <- synapser::synGetColumns('syn10232189')$asList()

# Remove the dataGroups column
cols.types <- removeColumnInSchemaColumns(cols.types, 'dataGroups')
cols.types <- removeColumnInSchemaColumns(cols.types, 'externalId')
cols.types <- removeColumnInSchemaColumns(cols.types, 'userSharingScope')
cols.types <- removeColumnInSchemaColumns(cols.types, 'validationErrors')
cols.types <- removeColumnInSchemaColumns(cols.types, 'substudyMemberships')
cols.types <- removeColumnInSchemaColumns(cols.types, 'dayInStudy')
cols.types <- removeColumnInSchemaColumns(cols.types, 'rawData')
cols.types <- removeColumnInSchemaColumns(cols.types, 'myTriggers.json.choiceAnswers')

##############
# Upload to Synapse
##############
# Github link
gtToken = 'github_token.txt';
githubr::setGithubToken(as.character(read.table(gtToken)$V1))
thisFileName <- 'data_curation/curate_triggers.R'
thisRepo <- getRepo(repository = "itismeghasyam/elevateMS_data_release", ref="branch", refName='master')
thisFile <- getPermlink(repository = thisRepo, repositoryPath=thisFileName)

## Upload new table to Synapse
triggers.tbl.syn.new <- synapser::synBuildTable(name = target.tbl.name,
                                               parent = parent.syn.id,
                                               values = triggers.tbl.new)

# Add back the new myTriggers.json.choiceAnswers column as a FILEHANDLEID
newSchema <- synapser::Schema(name = target.tbl.name,
                              columns = cols.types, # Specify column types
                              parent = parent.syn.id)
newCol <- synapser::Column(name = 'myTriggers.json.choiceAnswers',
                           columnType = 'FILEHANDLEID')
newSchema$addColumn(newCol)

triggers.tbl.syn.new$schema <- newSchema
tbl.syn.new <- synapser::synStore(triggers.tbl.syn.new)
act <- synapser::Activity(name = target.tbl.name,used = all.used.ids, executed = thisFile)
synapser::synSetProvenance(tbl.syn.new, activity = act)

# Remove local temp directory
unlink('hhh', recursive = T)

