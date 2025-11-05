#!/bin/bash
# Test script to verify Vercel build setup locally
# This simulates what happens in Vercel's build environment

set -e

echo "=========================================="
echo "Testing Vercel Build Setup Locally"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if we're in the project root
if [ ! -f "pubspec.yaml" ]; then
    echo -e "${RED}Error: pubspec.yaml not found. Please run this script from the project root.${NC}"
    exit 1
fi

echo -e "${YELLOW}Step 1: Testing install.sh${NC}"
echo "----------------------------------------"
if [ -f "install.sh" ]; then
    echo "✓ install.sh exists"
    if [ -x "install.sh" ]; then
        echo "✓ install.sh is executable"
    else
        echo -e "${YELLOW}Warning: install.sh is not executable. Making it executable...${NC}"
        chmod +x install.sh
    fi
    
    # Test if install.sh has syntax errors
    if bash -n install.sh 2>/dev/null; then
        echo "✓ install.sh has valid syntax"
    else
        echo -e "${RED}✗ install.sh has syntax errors${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ install.sh not found${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Step 2: Testing build.sh${NC}"
echo "----------------------------------------"
if [ -f "build.sh" ]; then
    echo "✓ build.sh exists"
    if [ -x "build.sh" ]; then
        echo "✓ build.sh is executable"
    else
        echo -e "${YELLOW}Warning: build.sh is not executable. Making it executable...${NC}"
        chmod +x build.sh
    fi
    
    # Test if build.sh has syntax errors
    if bash -n build.sh 2>/dev/null; then
        echo "✓ build.sh has valid syntax"
    else
        echo -e "${RED}✗ build.sh has syntax errors${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ build.sh not found${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Step 3: Testing vercel.json${NC}"
echo "----------------------------------------"
if [ -f "vercel.json" ]; then
    echo "✓ vercel.json exists"
    
    # Check if vercel.json is valid JSON
    if command -v python3 &> /dev/null; then
        if python3 -m json.tool vercel.json > /dev/null 2>&1; then
            echo "✓ vercel.json is valid JSON"
        else
            echo -e "${RED}✗ vercel.json is not valid JSON${NC}"
            exit 1
        fi
    elif command -v python &> /dev/null; then
        if python -m json.tool vercel.json > /dev/null 2>&1; then
            echo "✓ vercel.json is valid JSON"
        else
            echo -e "${RED}✗ vercel.json is not valid JSON${NC}"
            exit 1
        fi
    else
        echo -e "${YELLOW}Warning: Python not found, skipping JSON validation${NC}"
    fi
    
    # Check if vercel.json references our scripts
    if grep -q "install.sh" vercel.json && grep -q "build.sh" vercel.json; then
        echo "✓ vercel.json references install.sh and build.sh"
    else
        echo -e "${RED}✗ vercel.json doesn't reference install.sh or build.sh${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ vercel.json not found${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Step 4: Checking required files${NC}"
echo "----------------------------------------"
REQUIRED_FILES=("pubspec.yaml" "lib/main.dart")
MISSING_FILES=()

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "✓ $file exists"
    else
        echo -e "${RED}✗ $file not found${NC}"
        MISSING_FILES+=("$file")
    fi
done

if [ ${#MISSING_FILES[@]} -gt 0 ]; then
    echo -e "${RED}Error: Missing required files${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Step 5: Checking .gitignore${NC}"
echo "----------------------------------------"
if [ -f ".gitignore" ]; then
    echo "✓ .gitignore exists"
    if grep -q "flutter/" .gitignore || grep -q "/flutter" .gitignore; then
        echo "✓ flutter/ directory is in .gitignore"
    else
        echo -e "${YELLOW}Warning: flutter/ directory might not be in .gitignore${NC}"
    fi
    if grep -q "build/" .gitignore || grep -q "/build" .gitignore; then
        echo "✓ build/ directory is in .gitignore"
    else
        echo -e "${YELLOW}Warning: build/ directory might not be in .gitignore${NC}"
    fi
else
    echo -e "${YELLOW}Warning: .gitignore not found${NC}"
fi

echo ""
echo -e "${YELLOW}Step 6: Verifying script paths${NC}"
echo "----------------------------------------"
# Check if scripts use absolute paths
if grep -q '\$FLUTTER_SDK_PATH/bin/flutter' install.sh && grep -q '\$FLUTTER_SDK_PATH/bin/flutter' build.sh; then
    echo "✓ Scripts use absolute paths to Flutter"
else
    echo -e "${YELLOW}Warning: Scripts might not use absolute paths${NC}"
fi

echo ""
echo "=========================================="
echo -e "${GREEN}All checks passed!${NC}"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Commit and push your changes to GitHub"
echo "2. Vercel will automatically detect and deploy"
echo "3. Monitor the build in Vercel dashboard"
echo ""
echo "To test the build locally (optional):"
echo "  bash install.sh"
echo "  bash build.sh"
echo ""

