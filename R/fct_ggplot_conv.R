ggplot_conv <- function(plot) {
  # the pdf creation and the creation of the dummy_dev_id plus closing the 
  # graphics device is a workaround for an error which is thrown when 
  # as.ggplot() is used on RStudio connect
  
  # create a temporary pdf file
  pdf(tempfile(fileext=".pdf")) 
  # remember the device number
  dummy_dev_id = dev.cur()
  
  # when leaving the function, close our device (avoid leaving zombies)
  on.exit({                     
    if (dummy_dev_id %in% dev.list()) {
      dev.off(dummy_dev_id ) 
    } else warning("Dummy graphics device was closed 
                   by someone else. This should not have happened...")
  })
  
  return(as.ggplot(plot))
}