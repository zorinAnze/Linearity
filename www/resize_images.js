window.onload = function() {
  let images = document.querySelectorAll(".intro_img");

  images.forEach(function(img) {
    let initialWidth = img.naturalWidth;
    
    // Resize intro images to 40% of their size, or auto if they are smaller 
    // than 500px
    if(initialWidth > 500) {
      let newWidth = initialWidth * 0.4;
      img.style.width = newWidth + "px"; 
    } else {
      img.style.width = "auto";
    }
  });
};