#Load any required libraries

list.of.packages <- c()

new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages,repos='https://cloud.r-project.org')

librariesToLoad <- list.of.packages[!(list.of.packages %in% (.packages()))]
if(length(librariesToLoad)) sapply(librariesToLoad, function(libraryToLoad) {
  suppressPackageStartupMessages(library(libraryToLoad, character.only = TRUE))})

#Functions for use in estimating the ice mass balance of the Rolleston Glacier

#' Create a snow depth to density look up table 
#' 
#' [DepthToDensityLUT()] creates a depth to average density look-up-table based on some snow pit data. 
#' 
#' This function creates a table of densities that extrapolates the observed depths
#' from snow pit observations down to ExtrapolationDepth in 10 cm steps. The densities below the pit 
#' depth are taken as the average of the metre above.
#' This function also calculates the average density for each total depth (i.e. 
#' from the surface to the depth of the sample).
#' 
#' @param SinglePitData A data frame of snow pit density data where columns 3 to 9 are:
#' "Date" in dd/mm/yyyy format, "Easting(NZTM)", "Northing (NZTM)", "Elevation (mae)", 
#' "Depth to top (mm)", "Depth to bottom (mm)", "Density (kg m3).
#' The Depth columns are with regard the snow sample for which the density is provided.
#' @param ExtrapolationDepth. A value representing the depth in metres that the 
#' observed data needs to be extrapolated to. Defaults to 20.
#' @author Tim Kerr, \email{Tim.Kerr@@Rainfall.NZ}
#' @seealso
#' @return A dataframe with columns of "Depths", "Density", and "AveDensity
#' @keywords Keywords 

DepthToDensityLUT <- function(SinglePitData,
                              ExtrapolationDepth = 20)
{
  
  #Get the data of interest
  Densities <- SinglePitData[,c(3:9)]
  
  #Create a vector of depths from 0 to 20 m
  Depths <- seq(from = 0, to = ExtrapolationDepth * 1000, by = 100)
  
  #For the special case where only a single density observation is taken, all snow densities are the same
  if (nrow(Densities) == 1){
    DepthDensities <- data.frame(Depths=Depths,Density=rep(Densities$Density..kg.m3.,length(Depths)))
  } else {
    #The usual case where several density measurements have been taken to different depths
    DepthDensities <- approx(x=Densities$Depth.to.bottom..mm., 
                             y=Densities$Density..kg.m3., xout = Depths, rule = 2:1)
    
    #Convert to a dataframe
    DepthDensities <- as.data.frame(do.call(cbind, DepthDensities))
    names(DepthDensities) <- c("Depth","Density")
    
    #Extend the densities down to ExtrapolationDepth assuming each 100 mm deeper 
    # has a density that is the average of the metre above
    for (Depth in Depths[which(Depths > max(Densities$Depth.to.bottom..mm.))]) {
      #browser()
      DepthDensities[DepthDensities$Depth == Depth,'Density'] <- 
        mean(DepthDensities[(DepthDensities$Depth > (Depth - 1000) & DepthDensities$Depth < Depth),'Density'])
    }
  }
  #Round the density values
  DepthDensities$Density <- round(DepthDensities$Density)
  
  #Calculate the average density from the surface to each depth value
  DepthDensities$AveDensity <- sapply(DepthDensities$Depth, function(x) {
    mean(DepthDensities$Density[DepthDensities$Depth <= x])
  })
  
  return(DepthDensities)
}


#' Convert snow depth to snow water equivalent 
#' 
#' [SnowDepthToSWE()] Takes snow depth data and uses snow density data to convert
#'  it to snow water equivalent 
#' 
#' #This function takes a vector of snow depths from a specific date and uses the snow pit
#' data (with snow denity profiles) for that date to convert the depths to snow water equivalent. 
#' It uses the DepthToDensityLUT() function for the actual conversion.
#' 
#' @param SnowDepth a vector of snow depths in mm, defaults to c(0)
#' @param Date A date object, no default
#' @param PitData A list of snow pit density data. Each list element is for a unique date
#' @author Tim Kerr, \email{Tim.Kerr@@Rainfall.NZ}
#' @seealso DepthToDensityLUT()
#' @return A vector of snow water equivalent's
#' @keywords Keywords 

SnowDepthToSWE <- function(SnowDepth = 0, 
                           Date = NULL, 
                           PitData = NULL) {
  
  
  #Find which element of the PitData list has the  Pit Data for the date of interest
  PitDataIndex <- which(sapply(PitData, function(x) x$Date[1] == Date)==TRUE)
  
  #Create the Depth-to-Density look up table from the PitData
  DepthToDensity <- DepthToDensityLUT(PitData[[PitDataIndex]])
  
  #Get the average density for the depth of interest
  AverageDensity <- approx(DepthToDensity$Depth, DepthToDensity$AveDensity, xout = SnowDepth)$y
  SWE <- SnowDepth / 1000 * AverageDensity
}

#' Find area uncertainty associated with an imprecise outline 
#' 
#' [calculate_go3_buffer_uncertainty()] Find the area limits for an area outline when it
#' is moved inwards and outwards by buffer_dist 
#' 
#' This function estimates the area uncertainty associated with a glacier outline (go) having an uncertainty
#'  of "buffer_dist". Based on the GO-3 method described in section 2.3.2 of 
#'  Paul, F., Bolch, T., Briggs, K., Kääb, A., McMillan, M., McNabb, R., Nagler, T., 
#'   Nuth, C., Rastner, P., Strozzi, T., Wuite, J., 2017. Error sources and guidelines 
#'   for quality assessment of glacier area, elevation change, and velocity products 
#'   derived from satellite data in the Glaciers_cci project. Remote Sensing of Environment, 
#'   Earth Observation of Essential Climate Variables 203, 256–275. https://doi.org/10.1016/j.rse.2017.08.038
#'  The outlilne uncertainty is assumed to be normally distributed between the maxim and minimum areas
#'  possible given an outline varied by the buffer_dist.
#'  The buffer_dist relates to the uncertainty in delineating the glacier. If taken from satellite data
#'  then it should be the equivalent of half a pixel, but may be greater if delineation 
#'  is not obvious, e.g. at debris covered boundaries.
#'  If the outline is derived from an in-situ survey, then the buffer_dist might relate to the 
#'  difficulty the surveyor has in identifying the glacier boundary. For the Rolleston Glacier, a distance
#'  of 5 m is probably reasonable.
#' 
#' @param GlacierOutlinePolygon a terra vector object one or more polygons depicting glacier outlines
#' @param buffer_dist A distance (m) representing the uncertainty of the polygon_sf's outline
#' @author Kiri Shibahara, \email{ksh155@@uclive.ac.nz} and Tim Kerr, \email{Tim.Kerr@@Rainfall.NZ}
#' @seealso
#' @return Returns a dataframe with area uncertainty values for each polygon within polygon_sf
#' @keywords Keywords 

calculate_go3_buffer_uncertainty <- function(GlacierOutlinePolygon, 
                                             buffer_dist = 5) {

  n <- nrow(GlacierOutlinePolygon)
  results <- vector("list", n)
  
  area_mean <- terra::expanse(GlacierOutlinePolygon)
  area_max   <- terra::buffer(GlacierOutlinePolygon, width = buffer_dist) %>%
    terra::expanse()
  area_min   <- terra::buffer(GlacierOutlinePolygon, width = -buffer_dist) %>%
    terra::expanse()
  
    area_std <- 0.67 * (area_max - area_min)
    area_std_relative_pct <- 100 * area_std / area_mean
    
    results <- data.frame(
      BufferDist_m          = buffer_dist,
      Area_min_m2           = area_min,
      Area_mean_m2          = area_mean,
      Area_max_m2           = area_max,
      Area_STD_m2           = area_std,
      Area_STD_relative_pct = area_std_relative_pct
    )

  
  return(results)
}


    #' Very Brief description 
    #' 
    #' [NewFunction()] provide some extra detail here of what NewFunction does. 
    #' 
    #' Further details of NewFunction with any relevant links and background information
    #' 
    #' @param PARAMNAME1 Description of what PARAMNAME1 is for and what it's default is
    #' @param PARAMNAME1 Description of each of the parameters
    #' @author Tim Kerr, \email{Tim.Kerr@@Rainfall.NZ}
    #' @seealso
    #' @return Describe type of object that is returned
    #' @keywords Keywords 
    
    NewFunction <- function(PARAMNAME1 = NULL,
                            PARAMNAME2    = NULL)
    {
      
      
      #Do Stuff
      
      OutputObject <- NULL
      return(OutputObject)
    }


