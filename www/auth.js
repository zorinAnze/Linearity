const setCurrentUser = () => {
  var res = window.NIBRIam;
  Shiny.setInputValue(
    'current_user', 
    res, 
    { priority: 'event' }
  );
}
// To fix issue with microsoft edge and Chrome authentication
Shiny.addCustomMessageHandler('authenticate-user', function(msg){
  setCurrentUser();
});