# Cashout Performance Tuning

## Overview
Cashout Performance Tuning is a powerful software application designed to enhance the performance of vehicles through advanced tuning capabilities. It integrates seamlessly with several tools, including MegaLogViewer, HP Tuners, RaceRender, and more, allowing users to optimize their vehicle's performance effortlessly. This repository supports dynamic adjustments to automotive tuning parameters using advanced parsers and Supabase databases for metadata storage, alongside a comprehensive tuning guide covering stock & standalone ECU tuning, boost control, transmission tuning, and data-driven performance strategies. It also includes an interactive Excel tuning logger for real-time performance analysis.

## Key Features
- **Integration with Tools:** Easily connect with MegaLogViewer for data analysis, HP Tuners for vehicle tuning, and RaceRender for video rendering of vehicle performance.
- **File Upload API:** Supports `.html`, `.pdf`, `.txt`, and `.md` file uploads.
- **Data Parsing:** Extracts valuable tuning metadata, tables, and formulas (e.g., AFR tables from PDFs or boost formulas from MD files).
- **Supabase Integration:** Stores metadata for easy querying.
- **Compatibility:** Supports a variety of file formats, ensuring that users can work with the data they have without needing to convert it.
- **Interactive Excel Logger:** Enables real-time performance analysis.
- **Advanced Customization:** Offers extensive customization options, allowing users to modify parameters and settings to match their specific performance goals.

## Getting Started
1. Clone the repo: `git clone https://github.com/eedgurr/Cashout-Tuning.git`
2. Install dependencies: `pip install -r requirements.txt` (create a requirements.txt if not present, e.g., with pandas, supabase-py).
3. Download the Cashout Performance Tuning application from the official site (or build from source).
4. Follow the installation instructions provided in the setup wizard.
5. Launch the application, connect your vehicle's ECU, and run the parser: `python main.py --file example.pdf`.

## Future Updates
- **Excel/CSV Support:** Implement parsers for `.xlsx`, `.xls`, and `.csv` files.
- **Enhanced Table Parsing:** Add support for JSON and Lua workflows.
- **Frontend Integration:** Build a user-friendly web interface for uploading and visualizing parsed data.

## Code Improvements
- Refactor file parsing functions to handle edge cases more gracefully.
- Enhance regex for section identification in `.txt` and `.md` files.
- Modularize Supabase interactions for better scalability.
- Add unit tests for parsing functions to ensure reliability across file types.

## Debugging Microcontrollers
See [Microcontroller Debugging Techniques](docs/microcontroller_debugging.md) for tips on troubleshooting the embedded systems used with this project.


## Conclusion
Cashout Performance Tuning is the ultimate solution for car enthusiasts looking to fine-tune their vehicles for optimal performance. With easy integration, compatibility with various formats, advanced parsing and storage features, and forward-looking enhancements, it empowers users to achieve their tuning goals efficiently.

## Contributing
Contributions are welcome! Feel free to submit issues, pull requests, or suggestions for new features like additional tool integrations.
