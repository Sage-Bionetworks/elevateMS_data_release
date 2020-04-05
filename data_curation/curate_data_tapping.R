########################################################################
# elevateMS data release
# Purpose: To collate all tapping data tables in elevateMS project
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
target.tbl.name <- 'Tapping'
START_DATE = lubridate::ymd("2017-08-14")

##############
# Required functions
##############
# Find which columns are of a given type
# Adapted from https://github.com/brian-bot/mhc-sdata/blob/master/mhcCuration.R
whichColumns <- function(col_list, col_type){
  # col_list is the output of synGetColumns(*synID*)$asList()
  cc <- lapply(col_list, function(col_x){
    ifelse(col_x$columnType == col_type,
           return(col_x$name),
           return(NULL))
  })
  return(unlist(cc))
}

# Rename the column in a schema columns object 
# (i.e result of synGetColumns, or cols in Schema(.., columns = cols,..))
renameColumnInSchemaColumns <- function(SchemaColObj, oldName, newName){
  for(syn.col in SchemaColObj){
    if(syn.col$name == oldName){
      syn.col$name = newName
    }
  }
}

# Remove the column in a schema columns object 
# (i.e result of synGetColumns, or cols in Schema(.., columns = cols,..))
removeColumnInSchemaColumns <- function(SchemaColObj, colToRemove){
  
  colIdsToRemove <- NULL

  for(i in seq(length(SchemaColObj))){
    if(SchemaColObj[[i]]$name == colToRemove){
      colIdsToRemove <- c(colIdsToRemove,i)
    }
  }
  
  newObj <- SchemaColObj
  
  if(!is.null(colIdsToRemove)){
   newObj[[colIdsToRemove]] <- NULL
  }
  
  return(newObj)
}

# Given a result of a synTableQuery, replace all filehandles new filehandles
# associated with a copy of the file to be placed in parent.id (in Synapse)
getTableWithNewFileHandles <- function(ref.tbl.syn, parent.id){
  # ref.tbl.syn is the synapse object from synTableQuery  
  
  # Get table from Synapse Objects
  ref.tbl <- ref.tbl.syn$asDataFrame()
  
  # We will be using this later to specify column types for new table
  allCols <- synapser::synGetColumns(ref.tbl.syn$tableId)$asList()
  # Find all columns that are of type 'FILEHANDLEID' for the given table
  fhCols <- whichColumns(allCols, 'FILEHANDLEID')
  
  # Download all FILEHANDLEID type columns
  ref.json.loc = lapply(fhCols, function(col.name){
    tbl.files = synapser::synDownloadTableColumns(ref.tbl.syn, col.name) %>%
      lapply(function(x) data.frame(V1 = x)) %>%
      data.table::rbindlist(idcol = col.name) %>%
      plyr::rename(c('V1' = paste0(col.name, 'fileLocation')))
  })
  names(ref.json.loc) <- fhCols 
  
  # Add local filepath locations
  for(col.name in fhCols){
    ifelse(purrr::is_empty(ref.json.loc[[col.name]]),
           ref.tbl <- ref.tbl,
           ref.tbl <- ref.tbl %>% 
             dplyr::left_join(ref.json.loc[[col.name]])
    )
  }
  
  # Add any missing local filepath columns. This happens if all filepaths are NA,
  #  i.e no files for that column for the current filters
  missing.cols <- setdiff(paste0(fhCols, 'fileLocation'), colnames(ref.tbl))
  for(missing.col in missing.cols){
    ref.tbl[,missing.col] <- NA
  }
  
  # Upload a copy of the files to new Synapse project and get new filehandleIds
  fhs <- lapply(ref.tbl[,paste0(fhCols, 'fileLocation')], function(fpCol){
    a <- lapply(fpCol, function(fp){
      fh <- tryCatch(synapser::synUploadFileHandle(path= as.character(fp), parent=parent.id),
                     error = function(e){NULL})
      ifelse(is.null(fh),
             return(NA), # missing files handled as NAs
             return(fh$id))
    })
    return(unlist(a))
  })
  
  # Replace old filehandles with new ones
  for(fhCol in fhCols){
    ref.tbl[,fhCol] <- fhs[[paste0(fhCol, 'fileLocation')]]
    # print(fhCol)
  }
  
  # Remove local filepath and unneccessary columns
  ref.tbl <- ref.tbl %>% 
    dplyr::select(-dplyr::one_of(paste0(fhCols, 'fileLocation'))) %>% 
    dplyr::select(-ROW_ID, -ROW_VERSION)
  
  return(ref.tbl)
}

##############
# Download tapping tables from synapse
##############
# There are two tables in the elevateMS project

## v1 ('syn9765504')
tapping.tbl.v1.syn <- synapser::synTableQuery(paste(
  'select * from', 'syn9765504'
  # , " where healthCode = '41167e8c-f444-4a65-8689-1e3f7878d072'"
))
all.used.ids <- 'syn9765504'
tapping.tbl.v1.new <- getTableWithNewFileHandles(tapping.tbl.v1.syn
                                                 , parent.id = parent.syn.id) %>% 
  dplyr::rename(accelerometer_tapping_left.json.items = accelerometer_tapping_left.json,
                accelerometer_tapping_right.json.items = accelerometer_tapping_right.json)
# renaming to confirm to v2's nomenclature

## v2 ('syn10278765')
tapping.tbl.v2.syn <- synapser::synTableQuery(paste(
  'select * from', 'syn10278765'
  # , " where healthCode = '41167e8c-f444-4a65-8689-1e3f7878d072'"
))
all.used.ids <- c(all.used.ids, 'syn10278765')
tapping.tbl.v2.new <- getTableWithNewFileHandles(tapping.tbl.v2.syn,
                                                 parent.id = parent.syn.id) 

# Merge all the tables into a single one
tapping.tbl.new <- rbind(tapping.tbl.v1.new,tapping.tbl.v2.new)

# Filter based on START_DATE
tapping.tbl.new <- tapping.tbl.new %>% 
  dplyr::mutate(date_of_entry = as.Date(lubridate::as_datetime(metadata.json.startDate))) %>% 
  dplyr::filter(date_of_entry >= START_DATE) %>% 
  dplyr::select(-date_of_entry)

# Filter/Exclude Users based on Vanessa's offline analysis
to_exclude_users <- fread(synGet("syn17870261")$path)
all.used.ids <- c(all.used.ids, 'syn17870261')
tapping.tbl.new <- tapping.tbl.new %>% 
  dplyr::filter(!healthCode %in% to_exclude_users$healthCode) 

# Filter based on userSharingScope
tapping.tbl.new <- tapping.tbl.new %>% 
  dplyr::filter(userSharingScope == 'ALL_QUALIFIED_RESEARCHERS')

# Remove dataGroups column from all tables except Baseline Characteristics
# Remove unneccessary columns
tapping.tbl.new <- tapping.tbl.new %>% 
  dplyr::select(-dataGroups, 
                -metadata.json.dataGroups,
                -externalId,
                -userSharingScope,
                -validationErrors,
                -substudyMemberships,
                -dayInStudy)

##############
# Table Metadata (column names, types etc.,)
##############
# Get the reference column schema to use for the new table
cols.types <- synapser::synGetColumns('syn10278765')$asList()

# Remove the dataGroups column
cols.types <- removeColumnInSchemaColumns(cols.types, 'dataGroups')
cols.types <- removeColumnInSchemaColumns(cols.types, 'metadata.json.dataGroups')
cols.types <- removeColumnInSchemaColumns(cols.types, 'externalId')
cols.types <- removeColumnInSchemaColumns(cols.types, 'userSharingScope')
cols.types <- removeColumnInSchemaColumns(cols.types, 'validationErrors')
cols.types <- removeColumnInSchemaColumns(cols.types, 'substudyMemberships')
cols.types <- removeColumnInSchemaColumns(cols.types, 'dayInStudy')

# # Rename Columns of the table by removing "metadata.json", 
# # "json.items" and ".json" from column names
# oldColNames <- colnames(tapping.tbl.new)
# colnames(tapping.tbl.new)  <- gsub('metadata.json.', '',colnames(tapping.tbl.new))
# colnames(tapping.tbl.new) <- gsub('.json.items', '',colnames(tapping.tbl.new))
# colnames(tapping.tbl.new) <- gsub('.json', '',colnames(tapping.tbl.new))

# # Rename Columns in Schema
# cols.dat <- data.frame(oldName = oldColNames,
#                        newName = colnames(tapping.tbl.new))
# apply(cols.dat,1,function(x){
#   renameColumnInSchemaColumns(cols.types, x[['oldName']], x[['newName']])
# })

##############
# Upload to Synapse
##############
# Github link
gtToken = 'github_token.txt';
githubr::setGithubToken(as.character(read.table(gtToken)$V1))
thisFileName <- 'data_curation/curate_data_tapping.R'
thisRepo <- getRepo(repository = "itismeghasyam/elevateMS_data_release", ref="branch", refName='master')
thisFile <- getPermlink(repository = thisRepo, repositoryPath=thisFileName)

## Upload new table to Synapse
tapping.tbl.syn.new <- synapser::synBuildTable(name = target.tbl.name,
                                               parent = parent.syn.id,
                                               values = tapping.tbl.new)
tapping.tbl.syn.new$schema <- synapser::Schema(name = target.tbl.name,
                                               columns = cols.types, # Specify column types
                                               parent = parent.syn.id)
synapser::synStore(tapping.tbl.syn.new, used = all.used.ids, executed = thisFile)
