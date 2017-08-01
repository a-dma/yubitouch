package main

import (
    "fmt"
    "log"
    "os/exec"
    "os"
    "bufio"
    "strings"
)

func main() {
    
	/* Check path and arguments */
	
	path, err := exec.LookPath("gpg-connect-agent")
    if err != nil {
        log.Fatal("Can not find gpg-connect-agent. Aborting...")
    }
    //fmt.Println("gpg-connect-agent is available at", path)

    DO:="0"
    UIF:="0"

    nbArgs := len(os.Args)
    if nbArgs != 3 {
        log.Print("Wrong parameters")
        log.Fatal("usage: yubitouch {sig|aut|dec} {off|on|fix}")
    }
    
    if os.Args[1] == "sig" {
        DO = "D6"
    } else if os.Args[1] == "dec" {
        DO = "D7"
    } else if os.Args[1] == "aut" {
        DO = "D8"
    } else  {
        log.Fatal("Invalid value $1 (must be sig, aut, dec). Aborting...")
    }

    if os.Args[2] == "off" {
        UIF="00"
    } else if os.Args[2] == "on" {
        UIF="01"
    } else if os.Args[2] == "fix" {
        UIF="02"
    } else {
        log.Fatal("Invalid value $2 (must be off, on, fix). Aborting...")
    }

    /* Check PIN */
    reader := bufio.NewReader(os.Stdin)
    fmt.Print("Enter your admin PIN: ")
    PIN, _ := reader.ReadString('\n')
    PIN = strings.TrimRight(PIN, "\r\n")
    
    if len(PIN) == 0 {
        log.Fatal("Empty PIN. Aborting...")
    }
    
    fmt.Sprintf("%x", UIF)
    
    cmd := exec.Command(path, "--hex", "scd reset", "/bye")
    cmd.Run()
    
    checkPinApdu := fmt.Sprintf("scd apdu 00 20 00 83 %02x %x", len(PIN), PIN)
    //fmt.Println("send apdu :", checkPinApdu)
    checkPinCmd := exec.Command(path, "--hex", checkPinApdu, "/bye")
    checkPinOut, err:= checkPinCmd.Output()
    if err != nil {
        log.Fatal(err)
    }
    checkPinResult := fmt.Sprintf("%s", checkPinOut)
    if !strings.Contains(checkPinResult, "90 00") {
        log.Fatal("Wrong pin")
    }

	/* Change mode */
    changeModeApdu := fmt.Sprintf("scd apdu 00 da 00 %s 02 %s 20", DO, UIF)
	//fmt.Println("send apdu :", changeModeApdu)
    changeModeCmd := exec.Command(path, "--hex", changeModeApdu, "/bye")
    changeModeOut, err:= changeModeCmd.Output()
    if err != nil {
        log.Fatal(err)
    }
    changeModeResult := fmt.Sprintf("%s", changeModeOut)
    if !strings.Contains(changeModeResult, "90 00") {
        log.Fatal("Unable to change mode. Set to fix?")
    }
    fmt.Print("All is done!")
}
