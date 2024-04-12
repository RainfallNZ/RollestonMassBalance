# RollestonMassBalance
Mass Balance calculation scripts for the Rolleston Glacier.  
There are two scripts:  
1. `ObservationMap.rmd` This is an R markdown script used to create a map of the glacier and observation locations for inclusion in fieldwork reports.
2. `MassBalanceCalculator.Rmd` This is used to calculte mass balance quantities for supply to the [World Glacier Monitoring Service](https://wgms.ch/)

To follow is a general description of all processing that is required to determine the mass balance. This includes some manual GIS processing that hasn't yet been included in the scrpts.

## Glacier area
The glacier boundary was obtained from [Sentinel Hub](https://www.sentinel-hub.com/), and is from the normalised difference snow index (NDSI) from the Sentinel 2 observation taken on the 8th April 2022. The NDSI data were downloaded, converted to a polygon and smoothed.  
Note that prior to 2023, the glacier boundary was a manually digitised version based on Google Earth imagery, from GeoEye and dated 8th April 2009. 
## Maximum and minimum glacier elevation
The glacier area polygon was converted to a 5 m raster (set to snap to the 30 m DEM raster).
The 30 m DEM was resampled using bilinear interpolation to 5 m. Zonal statistics were used to find the minimum and maximum elevations of the glacier area.   
This doesn't change each year and is documented here merely as a record.
## Accumulation area
The accumulation area at the end of summer is found by intersecting the end-of-summer-snowline with the glacier area. The end-of-summer-snowline is ideally surveyed by GPS during the end-of-summer survey, or it may be able to be extracted from the end-of-summer-snowline-survey photograph, or even from satellite imagery.  
If the EOSS was GPS surveyed, then the survey needs to be opened in a GIS (e.g., ArcGIS or QGIS) and manually edited and intersected with the glacier area polygon to provide the accumulation area, which needs to be saved as a polygon, and the total area determined.  Use previous year's data to get the attribute name and formats correct.
## Mass balance point locations
The latitude and longitude coordinates for the stake, pit and probing locations need to be known. They should have been surveyed with a GPS. Elevations are good to know, but estimates extracted from the DEM are OK. Ideally GPS elevation values are converted to metres above sea level by adding the interpolated NZGEOID09 value for each location (16.12 m for the Rolleston Glacier)
## Winter balance  
The snow density data from the snow survey is extrapolated to depth in the script by assuming the snow density below the pit depth was the same as the average of the bottom metre of the pit.  
Snow depth values from the snow survey are converted to SWE by using the average density of the extrapolated snow pit data from the surface, down to the depth of interest.  
This processing is carried out using the R script `MassBalanceCalculator.Rmd`.  
The winter SWE values are interpolated across the glacier using Ordinary kriging with a spherical semivariogram and variable search radius to include up to 12 points. The resolution is set to 30 m. The extent is set to be outside the polygon outline of the glacier. The interpolated data is resampled to 5 m using bilinear interpolation, and then cut to the polygon outline. The mean SWE for the glacier area is the winter mass balance. This value, and the value at each stake is what gets reported to the World Glacier Monitoring Service.
## Summer balance
The summer balance is established for each stake location. 
*	The total amount of surface lowering that occurred at each stake location of the summer is determined (this includes consideration of any re-drilling of stakes mid-summer).
*	The snow depth at the end-of-winter is converted to swe using the winter density observations. This is the winter-swe
*	If the total surface lowering is greater than the end-of-winter snow depth then the difference must be ice, and so is converted to swe using 0.917 kg m-3 , the density of ice (Paterson 1994). The winter-swe plus this ice-swe is the total swe melt
*	If the surface lowering was less than the snow depth at the end of winter, then some snow will be left at the end of summer. This end-of-summer snow depth is converted to swe using the summer density data. The total SWE melt is the winter swe – summer swe.

This processing is carried out in the R script `MassBalanceCalculator.Rmd`.  
The probing area is interpolated to the accumulation area zone using ordinary kriging as per the winter accumulation.  -ve values are changed to 0
The summer snow depth is subtracted from the winter accumulation to give the summer mass balance (i.e. snow loss) for the accumulation area.  
A stake-melt to elevation relationship is established.
This is used to convert the 5 m DEM to a “Stake melt” raster, which is then clipped to the glacier area. These values are replaced with the accumulation area values where they exist. Combined, the mean over the glacier gave the summer balance.  
The mean loss in SWE for the glacier area is the summer mass balance. This and the melt at each stake is what is reported to the World Glacier Monitoring Service.
## Overall Mass Balance
The winter balance less the summer balance is the annual mass balance.
## References
Paterson, W. S. B. (1994). The Physics of Glaciers. Oxford, Butterworth-Heinemann.

