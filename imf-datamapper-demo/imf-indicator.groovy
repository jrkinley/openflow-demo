import groovy.json.*
import java.nio.charset.StandardCharsets

// Get the incoming flowfile
def flowFile = session.get()
if (!flowFile) return

try {
    // Read the JSON content from the flowfile
    def jsonContent = ""
    session.read(flowFile) { inputStream ->
        jsonContent = inputStream.getText(StandardCharsets.UTF_8.name())
    }
    
    // Parse the JSON
    def jsonSlurper = new JsonSlurper()
    def parsedJson = jsonSlurper.parseText(jsonContent)
    
    // Extract the values object
    def values = parsedJson.values
    
    // Flatten the nested structure and convert directly to JSON strings
    def outputLines = []
    
    values.each { indicator, countries ->
        countries.each { countryCode, years ->
            years.each { year, value ->
                // Round the value to avoid floating point precision issues
                def roundedValue = value instanceof Number ? 
                    Math.round(value * 10) / 10.0 : value
                
                // Create JSON string directly for each record
                def record = [
                    indicator: indicator,
                    country_code: countryCode,
                    year: year.toString(),
                    value: roundedValue,
                    ingestion_timestamp: new Date().format("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'")
                ]
                
                // Convert to JSON string immediately
                def jsonBuilder = new JsonBuilder(record)
                outputLines << jsonBuilder.toString()
            }
        }
    }
    
    // Join all JSON lines with newlines
    def outputContent = outputLines.join('\n')
    
    // Write the flattened data to a new flowfile
    flowFile = session.write(flowFile) { outputStream ->
        outputStream.write(outputContent.getBytes(StandardCharsets.UTF_8))
    }
    
    // Transfer to success
    session.transfer(flowFile, REL_SUCCESS)
    
} catch (Exception e) {
    log.error("Error processing JSON: ${e.message}", e)
    session.transfer(flowFile, REL_FAILURE)
}