# Tabscanner Examples

This directory contains example scripts demonstrating how to use the Tabscanner gem.

## Prerequisites

Before running these examples, make sure you have:

1. Installed the gem: `bundle install` or `gem install tabscanner`
2. Set your API key: `export TABSCANNER_API_KEY=your_api_key_here`

## Examples

### 1. Quick Test (`quick_test.rb`)

Verifies that the gem is properly configured:

```bash
ruby examples/quick_test.rb
```

### 2. Process Single Receipt (`process_receipt.rb`)

Processes a single receipt image (under 10 lines of code):

```bash
ruby examples/process_receipt.rb path/to/receipt.jpg
```

**Example output:**
```
Merchant: Coffee Shop
Total: $15.99
Items: 3
```

### 3. Batch Process Receipts (`batch_process.rb`)

Processes multiple receipts from a directory and saves results to CSV:

```bash
ruby examples/batch_process.rb receipts_directory
```

**Example output:**
```
Processing receipts from receipts...
Processing receipt1.jpg...
✅ Success: Coffee Shop - $15.99
Processing receipt2.jpg...
✅ Success: Gas Station - $45.67
✅ Processed 2 receipts successfully
📄 Results saved to receipt_results.csv
```

## Environment Variables

You can customize behavior with these environment variables:

- `TABSCANNER_API_KEY` - Your API key (required)
- `TABSCANNER_REGION` - API region (optional, default: 'us')
- `TABSCANNER_DEBUG` - Enable debug logging (optional, default: false)
- `DEBUG` - Enable debug mode for batch processing (optional)

## Error Handling

All examples include proper error handling for:

- Configuration errors (missing API key)
- Authentication errors (invalid API key)
- Validation errors (invalid files)
- Server errors (temporary failures)
- Timeout errors (processing takes too long)

## Creating Test Data

To test these examples, you can:

1. Use real receipt images (JPG, PNG formats)
2. Create a `receipts` directory with sample images
3. Use the debug mode to see detailed processing logs

## Line Count Verification

The simple receipt processing example (`process_receipt.rb`) is exactly 9 lines of functional code (excluding comments and blank lines), meeting the PRD requirement of under 10 lines for a complete round trip from file to parsed JSON.