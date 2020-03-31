package main

import (
    "fmt"; "log"; "net/http"; "github.com/gorilla/handlers"; "os";
    "os/exec";
)

func installFinished( resp http.ResponseWriter, req *http.Request ) {
	req.ParseForm()
	
	vmName := req.FormValue("vmName")
	
	resp.Write([]byte("ok<br>"))
	
	exec.Command("VBoxManage", "modifyvm", vmName, "--boot1", "disk", "--boot2", "net", "--boot3", "dvd" ).Run()
	
	resp.Write([]byte(vmName))
}

func main() {
    fmt.Println("Serving files in the current directory on port 8001")
    //http.Handle("/", http.FileServer(http.Dir("./web")))
    http.Handle(
    	"/", handlers.CombinedLoggingHandler(
    		os.Stderr,
    		http.FileServer(
    			http.Dir("./web") ) ) )
    http.HandleFunc( "/installFinished", installFinished )
    //err := http.ListenAndServe("10.40.13.175:8001", nil)
    err := http.ListenAndServe("localhost:8001", nil)
    if err != nil {
        log.Fatal("ListenAndServe: ", err, "\n")
    }
}