// Use this file to write queries to test your data connector
let
    //result = Teamleader_API_Connection.Contents("https://api.teamleader.eu/")
    result = Teamleader_API_Connection.GetCurrentApiKey("https://api.teamleader.eu/")
in
    result