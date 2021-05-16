*** Settings ***
Documentation   Orders robots from RobotSpareBin Industries Inc.
...             Saves the order HTML receipt as a PDF file.
...             Saves the screenshot of the ordered robot.
...             Embeds the screenshot of the robot to the PDF receipt.
...             Creates ZIP archive of the receipts and the images.
...             More info here: https://robocorp.com/docs/courses/build-a-robot
Library         RPA.Browser.Selenium
Library         RPA.HTTP
Library         RPA.Tables
Library         RPA.Desktop
Library         RPA.PDF
Library         RPA.Archive
Library         RPA.Dialogs
Library         RPA.Robocloud.Secrets

*** Keywords ***
Open robot order website
    # Get the bot main url from vault
    ${secret}=    Get Secret    botinfo
    #Open Available Browser        https://robotsparebinindustries.com
    Open Available Browser        ${secret}[orders-url]
    Click Element When Visible    //*[@id="root"]/header/div/ul/li[2]/a

Get orders
    # Allow bot to accept user input for orders url
    [Arguments]     ${csv_url}
    #Download     https://robotsparebinindustries.com/orders.csv    overwrite=True
    Download     ${csv_url}    overwrite=True
    ${table}=    Read Table From Csv    orders.csv
    [Return]     ${table}

Close alert
    Click Element When Visible    //*[@id="root"]/div/div[2]/div/div/div/div/div/button[1]

Fill order form
    [Arguments]    ${order}
    # Choose head
    Select From List By Value     //*[@id="head"]       ${order}[Head]
    # Choose body
    Click Element When Visible    //*[@id="root"]/div/div[1]/div/div[1]/form/div[2]/div/div[${order}[Body]]/label
    # Choose legs
    # - as the element id changes here, just tab to here
    RPA.Desktop.Press Keys    tab
    Type Text    ${order}[Legs]
    # Enter address
    Input Text                    //*[@id="address"]    ${order}[Address]

Preview order
    Click Button When Visible    //*[@id="preview"]

Submit order
    Click Button When Visible    //*[@id="order"]
    # order submission is successful if there is a receipt
    Wait Until Element Is Visible    //*[@id="receipt"]/h3

Order another bot
    Click Button When Visible    //*[@id="order-another"]

Save receipt as PDF file
    [Arguments]    ${order_number}
    ${receipt_html}=    Get Element Attribute    //*[@id="receipt"]    outerHTML
    Html To Pdf    ${receipt_html}    ${OUTPUT_DIR}${/}receipts${/}Order-${order_number}.pdf
    [Return]    ${OUTPUT_DIR}${/}receipts${/}Order-${order_number}.pdf

Take bot screenshot
    [Arguments]    ${order_number}
    Capture Element Screenshot    //*[@id="robot-preview-image"]  ${OUTPUT_DIR}${/}tmp${/}Image-${order_number}.png
    [Return]    ${OUTPUT_DIR}${/}tmp${/}Image-${order_number}.png

Embed bot to pdf
    [Arguments]    ${pdf_file}    ${bot_screenshot}
    Open Pdf     ${pdf_file}
    Add Watermark Image To Pdf    ${bot_screenshot}    ${pdf_file}
    Close Pdf    ${pdf_file}

Create ZIP of receipts
    Archive Folder With Zip    ${OUTPUT_DIR}${/}receipts    ${OUTPUT_DIR}${/}Orders.zip

Get csv url from user
    Create Form    Orders URL
    Add Text Input    URL of orders    orders_url
    &{response}=    Request Response
    [Return]    ${response["orders_url"]}

*** Tasks ***
Order robots from RobotSpareBin Industries Inc
    ${csv_url}=    Get csv url from user
    Open robot order website
    ${orders}=    Get orders    ${csv_url}
    FOR    ${order}    IN    @{orders}
        Close alert
        Fill order form    ${order}
        Preview order
        # it is possible that submitting the order will fail so bot has to retry
        Wait Until Keyword Succeeds    10x    1 sec    Submit order
        # store receipt as PDF
        ${pdffile}=        Save receipt as PDF file    ${order}[Order number]
        # screenshot bot
        ${screenshot}=        Take bot screenshot        ${order}[Order number]
        # embed bot to pdf
        Embed bot to pdf    ${pdffile}    ${screenshot}
        Order another bot
    END
    Create ZIP of receipts