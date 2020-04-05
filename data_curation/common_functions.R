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
