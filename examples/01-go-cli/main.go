package main

import (
	"flag"
	"fmt"
	"os"
	"runtime"
)

var version = "0.1.0"

func main() {
	showVersion := flag.Bool("version", false, "print version and exit")
	name := flag.String("name", "world", "name to greet")
	flag.Parse()

	if *showVersion {
		fmt.Printf("hello-go %s (%s/%s)\n", version, runtime.GOOS, runtime.GOARCH)
		os.Exit(0)
	}

	fmt.Printf("Hello, %s! This greeting is packaged as an AppImage.\n", *name)
	fmt.Printf("Built with Go %s, running on %s/%s.\n",
		runtime.Version(), runtime.GOOS, runtime.GOARCH)
}
