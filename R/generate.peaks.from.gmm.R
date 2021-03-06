.generate.peaks.from.gmm = function(
  dp,
  PARAMETERS,
  GENEINFO
){

  # Filtering by Threshold
  dp_data = dp[['dp_data']]
  dp_data = dp_data[dp_data$Weights > PARAMETERS$DP.WEIGHT.THRESHOLD,]
  dp_data = dp_data[complete.cases(dp_data),]
  if(nrow(dp_data) == 0){
    warning("No Peaks Survive Past The Weight Threshold", call. = TRUE, domain = NULL)
    return(list(GenomicRanges::GRanges(),  GenomicRanges::GRanges()))
  }
  dp_data = dp_data[order(-dp_data$Weights),]

  # Creating Peaks
  merged.peaks = data.frame(
    "chr" = GENEINFO$chr,
    "start" = round(dp_data$Mu - PARAMETERS$DP.N.SD*dp_data$Sigma),
    "end" = round(dp_data$Mu + PARAMETERS$DP.N.SD*dp_data$Sigma),
    "name" = GENEINFO$gene,
    "strand" = GENEINFO$strand,
    "weights" = dp_data$Weights,
    "i" = seq(1, nrow(dp_data), 1),
    stringsAsFactors = F
  )
  merged.peaks$start = ifelse(merged.peaks$start < 1, 1, merged.peaks$start)
  merged.peaks$end = ifelse(merged.peaks$end > GENEINFO$exome_length,  GENEINFO$exome_length, merged.peaks$end)
  merged.peaks = merged.peaks[!duplicated(merged.peaks[,c("chr", "start", "end", "name", "strand")]),]

  # Filtering peaks where 1 peak is within the other peak
  merged.peaks.gr =  GenomicRanges::makeGRangesFromDataFrame(merged.peaks, keep.extra.columns = T)
  within.peaks = GenomicRanges::findOverlaps(merged.peaks.gr, merged.peaks.gr, type = "within")
  within.peaks = within.peaks[S4Vectors::subjectHits(within.peaks) != S4Vectors::queryHits(within.peaks)]
  if(length(within.peaks) > 0){
    wid = IRanges::width(merged.peaks.gr)
    remove.elements = ifelse(wid[S4Vectors::queryHits(within.peaks)] > wid[S4Vectors::subjectHits(within.peaks)], S4Vectors::subjectHits(within.peaks), S4Vectors::queryHits(within.peaks))
    merged.peaks.gr = merged.peaks.gr[!1:length(merged.peaks.gr) %in% remove.elements]
  }

  # Subtracting Overlapping Regions
  merged.peaks.filtered.rna = GenomicRanges::GRanges()
  for ( i in 1:length(merged.peaks.gr)){
    if(i == 1){
      tmp.gr = merged.peaks.gr[1]
    }else{
      tmp.gr = GenomicRanges::setdiff(merged.peaks.gr[i], merged.peaks.gr[1:(i-1)])
      if(length(tmp.gr) > 0){S4Vectors::mcols(tmp.gr) = S4Vectors::mcols(merged.peaks.gr[i])}
    }
    merged.peaks.filtered.rna = c(merged.peaks.filtered.rna, tmp.gr)
  }

  # Removing peaks that are below resolution
  wid = IRanges::width(merged.peaks.filtered.rna)
  remove.elements = which(wid < PARAMETERS$RESOLUTION)
  merged.peaks.filtered.rna = merged.peaks.filtered.rna[!1:length(merged.peaks.filtered.rna) %in% remove.elements]

  return(merged.peaks.filtered.rna)
}
