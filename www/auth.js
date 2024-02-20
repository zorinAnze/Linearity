let checkDataInterval = setInterval(() => {
      if (window.NIBRIam) {
        Shiny.onInputChange('current_user', window.NIBRIam);
        clearInterval(checkDataInterval); // Stop checking once the data is sent
      }
    }, 1000); // Check every 1000 milliseconds (1 second)