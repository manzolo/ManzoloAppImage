# Build the hello-cpp binary. The AppImage assembly is in build.sh.

CXX      ?= g++
CXXFLAGS ?= -O2 -Wall -Wextra -std=c++17 -fdiagnostics-color=always
LDFLAGS  ?=
PKG       = gtk+-3.0

BIN_DIR ?= build
BIN      = $(BIN_DIR)/hello-cpp

SRC = src/main.cpp

GTK_CFLAGS := $(shell pkg-config --cflags $(PKG))
GTK_LIBS   := $(shell pkg-config --libs   $(PKG))

.PHONY: all clean
all: $(BIN)

$(BIN): $(SRC)
	@mkdir -p $(BIN_DIR)
	$(CXX) $(CXXFLAGS) $(GTK_CFLAGS) -o $@ $(SRC) $(GTK_LIBS) $(LDFLAGS)

clean:
	rm -rf $(BIN_DIR)
