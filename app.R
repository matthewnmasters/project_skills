library(shiny)
library(shinyjs)
library(shinyBS)
library(shinyWidgets)
library(shinyalert)
library(DT)
library(shinydashboard)
library(shinythemes)
library(dplyr)
library(stringr)
library(RSQLite)
rm(list=ls())


# The UI is pretty simple
# It only has two sections, the staff directory and the project management section
# I haven't done anything with project management

# I also haven't decided how I want to search for things.  We'll figure that out when we are done with everything else.

ui <- fluidPage(title = "Directory",
                h2("Staff directory and project database", align = "center"),
                theme = shinytheme("darkly"),
                tags$head(
                  tags$link(rel = "stylesheet", type = "text/css", href = "mystylesheet.css")),
                useShinyjs(),
                shinyalert::useShinyalert(),
                navbarPage(title = NULL,

                           #  Staff Directory
                           tabPanel("Staff directory",
                                    h4("View and edit the staff directory", align = "center"),
                                    HTML("<br>"),
                                    verticalLayout(
                                    div(class="button-container", align="right",
                                        circleButton("add_button", icon = icon("plus"), status = "success",
                                                     size = "sm", title = "label"),
                                    helpText("Click to add a new record", align = "right"))),
                                    HTML("<br>"),
                                    helpText("Please click on a 'view' icon to view selected record and the 'edit' button to add to the record"),
                                    dataTableOutput("mytable")),
                           
                           # Project database
                           tabPanel("Project database",
                                    h4("Project text goes here")))
)


                   


server <- function(input, output, session) {
  
  # Connect to the dataabase
  myDB <- dbConnect(RSQLite::SQLite(), "analysts.DB")
  

  # This is the main reactive dataset based on our analyst group
  analysts_df <- reactive({
    
    # Reactive to:
    input$add_button
    input$info_button
    input$edit_button
    
    analysts <- dbReadTable(myDB, "analysts")
    analysts$HireDate <- as.Date(analysts$HireDate, origin = "1970-01-01")
    analysts$Email <- str_replace(analysts$Email, 
                                  analysts$Email, 
                                  sprintf('<a href="mailto:%s">%s</a>',  analysts$Email, analysts$Email))
    analysts$view <- paste("<button id=\"info_button\" 
                                              type=\"button\" 
                                              class=\"btn btn-primary btn-sm\"
                                              onclick=\"Shiny.onInputChange(&quot;info_button&quot;,  Math.random())\"><i class=\"fa fa-address-card\"></i></button>")
    analysts$Edits <-paste("<button id=\"edit_button\" 
                           type=\"button\" 
                           class=\"btn btn-link btn-sm\"
                           onclick=\"Shiny.onInputChange(&quot;edit_button&quot;,  Math.random())\"><i class=\"fa fa-edit fa-2x\"></i></button>") 
    
    
    
    analysts <- dplyr::select(analysts, View = view, Name, Title, Department, Email, Phone, HireDate, Edits, Bio, row_id)
    return(analysts)
  })
  

# View a record -----------------------------------------------------------
  #  This "View" page will need to be formatted in some nice manner using standard UI code
  #  This is also where we will include whatever skill information is included in the skills table
  
  observeEvent(input$info_button, {
    
    sel_row <- input$mytable_row_last_clicked
    row_id <- analysts_df()[sel_row, "row_id"]
    table <- dbReadTable(myDB, "analysts")
    skills <- dbReadTable(myDB, "skills")
    
    
    # Profile values
    title <- table[table$row_id == row_id, "Title"]
    hire_date <- table[table$row_id == row_id, "HireDate"] %>%
      as.Date(origin = "1970-01-01")
    tenure <- (Sys.Date() - hire_date) %>% as.numeric()
    years <- floor(tenure / 365)
    days <- tenure %% 365
    time <- paste(years, "years and", days,"days")
    
    name <- table[table$row_id == row_id, "Name"]
    email <- table[table$row_id == row_id, "Email"]
    department <- table[table$row_id == row_id, "Department"]
    
    bio <- table[table$row_id == row_id, "Bio"]
    
    #Three groups of skills:
    # Analysis
    # Coding
    # Project Management
    
    # This will pull the skills for each person
    # If no skills have been entered, it will initialize the database with that name
    skills <- dplyr::filter(skills, Name == name)
    if (nrow(skills) == 0) {
      skills <- data.frame(Name = name,
                           Type = "",
                           Skills = "",
                           row_id = as.character(row_id))
      dbAppendTable(myDB, "skills", skills)
    }
    coding <- filter(skills, Type == "Coding")
    coding <- paste(coding$Skills, collapse = ", ")

    analysis <- filter(skills, Type == "Analysis")
    analysis <- paste(analysis$Skills, collapse = ", ")
    
    projMan <- filter(skills, Type == "Project Management")
    projMan <- paste(projMan$Skills, collapse = ", ")
        
    # I'm doing this with html tags, but we could create an htmlTemplate() within the 
    # fluidPage() to be much nicer
    showModal(
      modalDialog(id = "profile_form",
                  title = NULL,
                  footer = modalButton("Dismiss"),
                  easyClose = TRUE,
                  div(
                    fluidPage(
                      theme = shinytheme("darkly"),
                      HTML('<center><img src="ACS.png"></center>'),
                      h3("Employee information", align = "center"),
                      h4(name, align = "center"),
                      h5(title, align = "center"),
                      h5(tags$a(href=sprintf("mailto:%s", email), email)),
                      h5(department),
                      h5(paste("With ACS for",time),
                      HTML("<br><br>"),
                      verticalLayout(
                      h4(strong("Bio")),
                      h5(bio)),
                      HTML("<br><br>"),
                      verticalLayout(
                        fluidRow(
                          column(4,
                                 h4("Coding skills")),
                          column(8,
                                 helpText(coding))
                        ),
                        fluidRow(
                          column(4,
                                 h4("Analysis skills")),
                          column(8,
                                 helpText(analysis))
                        ),
                        fluidRow(
                          column(4,
                                 h4("Project management skills")),
                          column(8,
                                 helpText(projMan))
                        )))))))
                       
  })
  
  
  
 # Edit a record -----------------------------------------------------------
 # This will edit a record.  Sort of does the same thing we had before, only in the mondal window 
  observeEvent(input$edit_button, {
    
    
    sel_row <- input$mytable_row_last_clicked
    row_id <- analysts_df()[sel_row, "row_id"]
    table <- dbReadTable(myDB, "analysts")
    skills <- dbReadTable(myDB, "skills")
    
    # Profile values
    title <- table[table$row_id == row_id, "Title"]
    name <- table[table$row_id == row_id, "Name"]
    email <- table[table$row_id == row_id, "Email"]
    department <- table[table$row_id == row_id, "Department"]
    phone <- table[table$row_id == row_id, "Phone"]
    
    bio <- table[table$row_id == row_id, "Bio"]
    
    #Three groups of skills:
    # Analysis
    # Coding
    # Project Management
    
    # This will pull the skills for each person
    # If no skills have been entered, it will initialize the database with that name
    skills <- dplyr::filter(skills, Name == name)
    if (nrow(skills) == 0) {
      skills <- data.frame(Name = name,
                           Type = "",
                           Skills = "",
                           row_id = as.character(row_id))
      dbAppendTable(myDB, "skills", skills)
    }
    
              
   # Initialize the check box entries
    initialCodes <- c("SAS", "R", "Python", "C", "C++", "MATLAB")
    initialAnalysis <- c("Logistic Regression", "ANOVA", "Time Series",
                         "Survival Analysis", "Machine Learning", "GIS")
    initialProjects <- c("PMP", "Grant Writing", "Grant Administration",
                         "Hiring", "Program Design", "Event Planning")
    
    # Keep a running tab of the skills people have included
    allcoding <- filter(skills, Type == "Coding" & Skills != "")$Skills %>%
      c(initialCodes)
      
    allanalysis <- filter(skills, Type == "Analysis" & Skills != "")$Skills %>%
      c(initialAnalysis)

    allprojMan <- filter(skills, Type == "Project Management" & Skills != "")$Skills %>%
      c(initialProjects)
    
    
    # Just the skills of the person of interest
    mySkills <- filter(skills, Name == name & Skills != "") 
    coding <- filter(skills, Type == "Coding")

    analysis <- filter(skills, Type == "Analysis")

    projMan <- filter(skills, Type == "Project Management")

    
    # Again, I did this all with simple Shiny code, but I think we could use an HTMLtemplate to do a lot better
    showModal(
      modalDialog(id = "profile_form",
                  title = NULL,
                  footer = modalButton("Dismiss"),
                  easyClose = TRUE,
                  div(
                    fluidPage(
                      theme = shinytheme("darkly"),
                      splitLayout(
                      textInput(inputId = "newname",
                                label = "Name",
                                value = name),
                      textInput(inputId = "newtitle",
                                label = "Job title",
                                value = title)),
                      splitLayout(
                      textInput(inputId = "newemail",
                                label = "Email address",
                                value = email),
                      textInput(inputId = "newdepartment",
                                label = "Department",
                                value = department)
                      ),
                      textInput(inputId = "newphone",
                                label = "Preferred phone number",
                                value = phone),
                      HTML("<br>"),
                      textAreaInput(inputId = "newbio",
                                    label = "Introduce yourself (bio)",
                                    value = bio,
                                    height = '400px'),
                      HTML("<br><br>"),
                      h3("Skills database", align = "center"),
                      splitLayout(
                        verticalLayout(
                      checkboxGroupInput(inputId = "newCoding",
                                         label = "Coding skills",
                                         choices = c(unique(allcoding), "Other (specify)"),
                                         selected = coding$Skills),
                      uiOutput("codingOther")),
                      verticalLayout(
                      checkboxGroupInput(inputId = "newAnalysis",
                                         label = "Analysis skills",
                                         choices = c(unique(allanalysis), "Other (specify)"),
                                         selected = analysis$Skills),
                      uiOutput("analysisOther")),
                      verticalLayout(
                      checkboxGroupInput(inputId = "newProjMan",
                                         label = "Project Management Skills",
                                         choices = c(unique(allprojMan), "Other (specify)"),
                                         selected = projMan$Skills),
                      uiOutput("projManOther"))),
                      actionButton("save_button", "Update your information", icon=icon("save"),
                                   status = "success")
                    ))))
    
    

    output$codingOther <- renderUI({
      validate(need(input$newCoding, ""))
      if ("Other (specify)" %in% input$newCoding) {
        textInput(inputId = "codingOther",
                  label = "Please specify")
      }
    })
    output$analysisOther <- renderUI({
      validate(need(input$newAnalysis, ""))
      if ("Other (specify)" %in% input$newAnalysis) {
        textInput(inputId = "analysisOther",
                  label = "Please specify")
      }
    })
    output$projManOther <- renderUI({
      validate(need(input$newProjMan, ""))
      if ("Other (specify)" %in% input$newProjMan) {
        textInput(inputId = "projManOther",
                  label = "Please specify")
      }
    })
    
    

    
    # Save the data
    observeEvent(input$save_button, {
      
      oldtable <- dbReadTable(myDB, "analysts") 
      oldskills <- dbReadTable(myDB, "skills")
        oldskills <- oldskills[oldskills$row_id == row_id,]
      
      newname <- input$newname
      newtitle <- input$newtitle
      newemail <- input$newemail
      newdepartment <- input$newdepartment
      newbio <- input$newbio
      newphone <- input$newphone
      
      newtable <- oldtable[oldtable$row_id == row_id,]
      newtable$Name <- newname
      newtable$Title <- newtitle
      newtable$Email <- newemail
      newtable$Phone <- newphone
      newtable$Bio <- newbio
      newtable$Department <- newdepartment
      
      oldtable <- oldtable[oldtable$row_id != row_id,]
      final <- bind_rows(oldtable,newtable)
      final <- final[order(final$row_id),]
      dbWriteTable(myDB, "analysts", final, overwrite = T)
      
      # Now compile the skills
      codingString <- input$newCoding
      codingString <- codingString[codingString != "Other (specify)"]
      otherCodes <- ifelse(is.null(input$codingOther), "", input$codingOther)
      codingString <- c(codingString, otherCodes)
      codingString <- data.frame(Name = newname,
                                 Type = "Coding",
                                 Skills = codingString,
                                 row_id = as.character(row_id))
      
      
      analyticString <- input$newAnalysis
      analyticString <- analyticString[analyticString != "Other (specify)"]
      otherAnalysis <- ifelse(is.null(input$analysisOther), "", input$analysisOther)
      analyticString <- c(analyticString, otherAnalysis)
      analyticString <- data.frame(Name = newname,
                                 Type = "Analysis",
                                 Skills = analyticString,
                                 row_id = as.character(row_id))
      
      projString <- input$newProjMan
      projString <- projString[projString != "Other (specify)"]
      otherProj <- ifelse(is.null(input$projManOther), "", input$projManOther)
      projString <- c(projString, otherProj)
      projString <- data.frame(Name = newname,
                                   Type = "Project Management",
                                   Skills = projString,
                                   row_id = as.character(row_id))
      newSkills <- rbind(codingString, analyticString, projString)
      
      
      tempskills <- dbReadTable(myDB, "skills") 
      tempskills <- tempskills[tempskills$row_id != row_id,]
      
      final <- rbind(tempskills, newSkills)
      final <- final[final$Skills != "", ]
      dbWriteTable(myDB, "skills", final, overwrite = T)
      
      session$reload()
      
    })
  })
  

# Add a record ------------------------------------------------------------
# This will need a bit of work, since we need to include all the things in the database
# But for a first pass this isn't too bad

  observeEvent(input$add_button, {

    
    skills <- dbReadTable(myDB, "skills")
    
    
    # Initialize the check box entries
    initialCodes <- c("SAS", "R", "Python", "C", "C++", "MATLAB")
    initialAnalysis <- c("Logistic Regression", "ANOVA", "Time Series",
                         "Survival Analysis", "Machine Learning", "GIS")
    initialProjects <- c("PMP", "Grant Writing", "Grant Administration",
                         "Hiring", "Program Design", "Event Planning")
    
    
    coding <- c(initialCodes,
               dplyr::filter(skills, Type == "Coding")$Skills) %>%
               unique()
    coding <- coding[coding != ""]
    analysis <-c(initialAnalysis,
                 dplyr::filter(skills, Type == "Analysis")$Skills) %>%
                 unique()
    analysis <- analysis[analysis != ""]
    projman <- c(initialProjects,
                 dplyr::filter(skills, Type == "Project Management")$Skills) %>%
                 unique()
    projman <- projman[projman != ""]
    
    
    
    
    showModal(
      modalDialog(id = "new_form",
                  title = NULL,
                  footer = modalButton("Dismiss"),
                  easyClose = TRUE,
                  div(
                    fluidPage(
                      theme = shinytheme("darkly"),
                      splitLayout(
                        textInput(inputId = "addname",
                                  label = "Preferred name",
                                  placeholder = "Jane Smith",
                                  value = ""),
                        textInput(inputId = "addtitle",
                                  label = "Job title",
                                  placeholder = "Scientist",
                                  value = "")
                      ),
                      HTML("<br><br>"),
                      splitLayout(
                        textInput(inputId = "adddepartment",
                                  label = "OCMSO Department",
                                  placeholder = "Patient services, Epidemiology, etc",
                                  value = ""),
                        textInput(inputId = "addemail",
                                  label = "E-mail address",
                                  placeholder = "jane.smith@cancer.org",
                                  value = "")
                                ),
                      HTML("<br><br>"),
                      splitLayout(
                        textInput(inputId = "addphone",
                                  label = "Preferred phone number",
                                  placeholder = "555-555-5555",
                                  value = ""),
                        textInput(inputId = "addfunction",
                                  label = "Job function",
                                  placeholder = "Intramural Research",
                                  value = ""),
                        dateInput(inputId = "addhiredate",
                                  label = "Hire date",
                                  value = Sys.Date())
                      ),
                      HTML("<br><br>"),
                      textAreaInput(inputId = "addbio",
                                     label = "Tell us a little about yourself",
                                     placeholder = "I like cats more than dogs",
                                     height = '400px',
                                     value = ""),
                      HTML("<br><br>"),
                      h3("Skills database", align = "center"),
                      splitLayout(
                        verticalLayout(
                          checkboxGroupInput(inputId = "addCoding",
                                             label = "Coding skills",
                                             choices = c(coding, "Other (specify)"),
                                             selected = NULL),
                          uiOutput("addcodingOther")),
                        verticalLayout(
                          checkboxGroupInput(inputId = "addAnalysis",
                                             label = "Analysis skills",
                                             choices = c(analysis, "Other (specify)"),
                                             selected = NULL),
                          uiOutput("addanalysisOther")),
                        verticalLayout(
                          checkboxGroupInput(inputId = "addProjMan",
                                             label = "Project Management Skills",
                                             choices = c(projman, "Other (specify)"),
                                             selected = NULL),
                          uiOutput("addprojManOther"))),
                      HTML("<br><br>"),
                      actionButton(inputId = "save_new",
                                   label = "Save your information",
                                   icon = icon("save"),
                                   status = "success")
                    ))))
    
    
    output$addcodingOther <- renderUI({
      validate(need(input$addCoding, ""))
      if ("Other (specify)" %in% input$addCoding) {
        textInput(inputId = "addcodingOther",
                  label = "Please specify")
      }
    })
    output$addanalysisOther <- renderUI({
      validate(need(input$addAnalysis, ""))
      if ("Other (specify)" %in% input$addAnalysis) {
        textInput(inputId = "addanalysisOther",
                  label = "Please specify")
      }
    })
    output$addprojManOther <- renderUI({
      validate(need(input$addProjMan, ""))
      if ("Other (specify)" %in% input$addProjMan) {
        textInput(inputId = "addprojManOther",
                  label = "Please specify")
      }
    })
    
    

observeEvent(input$save_new, {

  table <- dbReadTable(myDB, "analysts")
  maxRow <- as.numeric(max(table$row_id))

  foo <- data.frame(Name = input$addname,
                    Title = input$addtitle,
                    Department = input$adddepartment,
                    Email = input$addemail,
                    Phone = input$addphone,
                    Function = input$addfunction,
                    HireDate = input$addhiredate,
                    row_id = as.character(maxRow + 1),
                    Bio = input$addbio)

  # Save it to the SQL file
  dbAppendTable(myDB, "analysts", foo)

  
  
  
  # Now compile the skills
  codingString <- input$addCoding
  codingString <- codingString[codingString != "Other (specify)"]
  otherCodes <- ifelse(is.null(input$addcodingOther), "", input$addcodingOther)
  codingString <- c(codingString, otherCodes)
  codingString <- data.frame(Name = input$addname,
                             Type = "Coding",
                             Skills = codingString,
                             row_id = as.character(row_id))
  
  
  analyticString <- input$addAnalysis
  analyticString <- analyticString[analyticString != "Other (specify)"]
  otherAnalysis <- ifelse(is.null(input$addanalysisOther), "", input$addanalysisOther)
  analyticString <- c(analyticString, otherAnalysis)
  analyticString <- data.frame(Name = input$addname,
                               Type = "Analysis",
                               Skills = analyticString,
                               row_id = as.character(row_id))
  
  projString <- input$ProjMan
  projString <- projString[projString != "Other (specify)"]
  otherProj <- ifelse(is.null(input$addprojManOther), "", input$addprojManOther)
  projString <- c(projString, otherProj)
  projString <- data.frame(Name = input$addname,
                           Type = "Project Management",
                           Skills = projString,
                           row_id = as.character(row_id))
  newSkills <- rbind(codingString, analyticString, projString)
  
  
  tempskills <- dbReadTable(myDB, "skills") 
  tempskills <- tempskills[tempskills$row_id != row_id,]
  
  final <- rbind(tempskills, newSkills)
  final <- final[final$Skills != "", ]
  
  dbWriteTable(myDB, "skills", final, overwrite = T)
  
  
  session$reload()
  

})

      })


 
  # Data table output -------------------------------------------------------
  # This renders the initial table - pretty straightforward
  
  output$mytable <- DT::renderDataTable({
    
    df <- analysts_df() %>% 
      select(-row_id, -Bio) %>%
      DT::datatable(
      rownames = FALSE,
      escape = FALSE,
      selection = "single",
      options = list(searching = TRUE, 
                     lengthChange = FALSE,
                     pageLength = 20,
                     autoWidth = FALSE,
                     initComplete = JS(
                       "function(settings, json) {",
                       "$(this.api().table().header()).css({'background-color': '#375a7f', 'color': '#fff'});",
                       "}")))
  })
  
  
}
shinyApp(ui, server)