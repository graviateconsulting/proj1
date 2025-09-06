# Project Name

## Overview
This project is designed to handle data extraction and ingestion processes for serialized device history data. It is structured into different modules to facilitate code organization and reusability.

## Folder Structure
- `src/main/scala/com/tmobile/common/`: Contains common utility files or classes that can be shared across different modules in the project.
- `src/main/scala/com/tmobile/dlmExtract/`: Holds files related to the data extraction logic, including classes and functions for reading data from various sources.
- `src/main/scala/com/tmobile/dlmIngestion/`: Contains the `serializeddevicehistoryV2Ingest.scala` file, which is responsible for ingesting serialized device history data.

## Setup Instructions
1. Ensure you have Java and Scala installed on your machine.
2. Set up Apache Spark in your environment.
3. Clone the repository to your local machine.
4. Navigate to the project directory.

## Usage
- To run the data ingestion process, execute the `serializeddevicehistoryV2Ingest` object.
- Provide the necessary configuration files and parameters as required by the application.

## Contributing
Contributions are welcome! Please submit a pull request or open an issue for any enhancements or bug fixes.

## License
This project is licensed under the MIT License. See the LICENSE file for more details.