# Community Report Workflow

This automated workflow generates comprehensive community contribution reports for the repository, providing insights into contributions from both Google employees and the broader community.

## Features

### 📊 Comprehensive Reporting
- **Issues**: Tracks new issues created during the specified period
- **Pull Requests**: Monitors new pull requests submitted
- **Discussions**: Includes GitHub Discussions activity
- **User Classification**: Automatically distinguishes between Google employees and community contributors

### 🚀 Performance Optimizations
- **Caching**: Implements user status caching to reduce API calls
- **Retry Logic**: Handles API failures with exponential backoff
- **Timeouts**: Prevents hanging on slow API responses
- **Progress Tracking**: Shows processing progress for large datasets

### 🛠️ Enhanced Error Handling
- **Input Validation**: Validates all inputs before processing
- **Graceful Degradation**: Continues processing even if some data sources fail
- **Detailed Logging**: Provides comprehensive status updates and error messages
- **Debug Mode**: Optional verbose output for troubleshooting

### 📈 Rich Analytics
- **Key Metrics**: Community contribution percentage, most active categories
- **Performance Stats**: API usage statistics and cache hit rates
- **Trend Analysis**: Identifies patterns in contribution data
- **Data Quality**: Reports on the reliability of collected data

## Usage

### Automatic Execution
The workflow runs automatically every Monday at 12:00 UTC, generating a weekly report for the past 7 days.

### Manual Execution
You can manually trigger the workflow from the Actions tab with custom parameters:

1. Go to the **Actions** tab in your repository
2. Select **Generate Weekly Community Report 📊**
3. Click **Run workflow**
4. Configure parameters:
   - **Days**: Number of days to look back (1-365, default: 7)
   - **Debug**: Enable verbose logging (default: false)

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `days` | number | 7 | Number of days to look back for data collection |
| `debug` | boolean | false | Enable debug mode with verbose logging |

## Output

### Generated Report
The workflow produces a markdown report containing:

- **Summary Table**: Contributions by category and contributor type
- **Key Metrics**: Percentages and trends
- **Data Quality**: Information about cache performance and API usage

### Automated Actions
When run on schedule, the workflow:
1. **Creates an Issue**: Posts the report as a new issue with appropriate labels
2. **AI Analysis**: Uses Gemini to provide insights and recommendations
3. **Optional Discussion**: Can be configured to post to GitHub Discussions

## Configuration

### Required Secrets
- `APP_ID`: GitHub App ID for authentication
- `PRIVATE_KEY`: GitHub App private key
- `GEMINI_API_KEY`: API key for Gemini AI analysis
- Additional OTLP secrets for telemetry (optional)

### Permissions
The workflow requires the following permissions:
- `issues: write` - To create report issues
- `pull-requests: read` - To read PR data
- `discussions: read` - To read discussion data
- `contents: read` - To access repository content
- `id-token: write` - For OIDC authentication

## File Structure

```
.github/
├── workflows/
│   └── community-report.yml          # Main workflow definition
└── scripts/
    └── generate-community-report.sh  # Extracted report generation logic
```

## Customization

### Modifying the Report Format
Edit the `REPORT_BODY` section in `generate-community-report.sh` to customize the output format.

### Adding Data Sources
Extend the script to include additional GitHub API endpoints such as:
- Comments and reviews
- Reactions and mentions
- Commit activity
- Repository stars and forks

### Changing Notification Behavior
- Modify the issue creation step to change labels or assignees
- Uncomment the discussion posting section to enable discussions
- Add Slack/Discord notifications by adding webhook steps

### Adjusting User Classification
The workflow currently checks membership in the `googlers` organization. Modify the `check_googler_status()` function to use different criteria.

## Troubleshooting

### Common Issues

1. **API Rate Limiting**: The workflow includes retry logic and caching to minimize API calls
2. **Large Repositories**: Increase timeout values if processing takes too long
3. **Missing Data**: Check the debug output to identify failed API calls

### Debug Mode
Enable debug mode for detailed logging:
1. Run the workflow manually
2. Set the `debug` parameter to `true`
3. Check the workflow logs for detailed information

### Performance Monitoring
The workflow reports performance metrics including:
- Number of API calls made
- Cache hit rate
- Processing time statistics

## Contributing

To improve this workflow:
1. Test changes in a fork first
2. Use debug mode to validate behavior
3. Consider impact on API rate limits
4. Update documentation for new features

## License

This workflow is part of the gemini-cli project and follows the same license terms.
