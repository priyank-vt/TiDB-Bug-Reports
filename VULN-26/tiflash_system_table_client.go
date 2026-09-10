package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"time"

	"github.com/pingcap/kvproto/pkg/kvrpcpb"
	"github.com/pingcap/kvproto/pkg/tikvpb"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

func main() {
	addr := flag.String("addr", "127.0.0.1:3930", "tiflash flash service address")
	sqlFile := flag.String("sql-file", "", "file containing SQL to execute")
	outFile := flag.String("out", "/dev/stdout", "output file for response data")
	flag.Parse()

	sqlBytes, err := os.ReadFile(*sqlFile)
	if err != nil {
		fmt.Fprintf(os.Stderr, "read sql-file: %v\n", err)
		os.Exit(1)
	}

	conn, err := grpc.NewClient(*addr, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		fmt.Fprintf(os.Stderr, "grpc dial: %v\n", err)
		os.Exit(1)
	}
	defer conn.Close()

	client := tikvpb.NewTikvClient(conn)
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	start := time.Now()
	resp, err := client.GetTiFlashSystemTable(ctx, &kvrpcpb.TiFlashSystemTableRequest{
		Sql: string(sqlBytes),
	})
	if err != nil {
		fmt.Fprintf(os.Stderr, "GetTiFlashSystemTable RPC error: %v\n", err)
		os.Exit(2)
	}
	fmt.Fprintf(os.Stderr, "RPC OK in %v, response bytes: %d\n", time.Since(start), len(resp.Data))

	f, err := os.Create(*outFile)
	if err != nil {
		fmt.Fprintf(os.Stderr, "create out: %v\n", err)
		os.Exit(3)
	}
	defer f.Close()
	if _, err := f.Write(resp.Data); err != nil {
		fmt.Fprintf(os.Stderr, "write: %v\n", err)
		os.Exit(4)
	}
	fmt.Fprintf(os.Stderr, "saved to %s\n", *outFile)
}
