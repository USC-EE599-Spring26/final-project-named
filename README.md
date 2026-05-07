<!--
Name of your final project
-->
# ThyroRecover
![Swift](https://img.shields.io/badge/swift-5.5-brightgreen.svg) ![Xcode 13.2+](https://img.shields.io/badge/xcode-13.2%2B-blue.svg) ![iOS 15.0+](https://img.shields.io/badge/iOS-15.0%2B-blue.svg) ![watchOS 8.0+](https://img.shields.io/badge/watchOS-8.0%2B-blue.svg) ![CareKit 2.1+](https://img.shields.io/badge/CareKit-2.1%2B-red.svg) ![ci](https://github.com/netreconlab/CareKitSample-ParseCareKit/workflows/ci/badge.svg?branch=main)

## Description
<!--
Give a short description of what your project accomplishes and what tools it uses. Basically, what problems does it solve and why is it different from other apps in the app store?
-->
The five-year survival rate of thyroid cancer exceeds 97%, but long-term self-management after thyroidectomy remains critical for preventing complications and recurrence. However, existing mobile health applications for post-thyroidectomy rehabilitation lack targeted multidimensional support, particularly in personalized symptom tracking, intelligent follow-up scheduling, and psychological assistance. These gaps lead to significant deficiencies in out-of-hospital management, including suboptimal patient adherence, fragmented clinician-patient communication, and a scarcity of standardized self-management tools. 
To address these challenges, we propose ThyroRecover, a specialized iOS rehabilitation application built on Apple’s open-source CareKit framework. Based on the OCKSample project, ThyroRecover provides ERAS-aligned recovery tasks, including tracking voice and swallowing discomfort, setting early ambulation goals, hydration reminders, and structured daily check-ins. The system further integrates ResearchKit to support thyroid anatomy education, neck range-of-motion assessment, and structured symptom surveys, while SwiftUI Charts are used to present multidimensional recovery trends. In addition, ThyroRecover incorporates authoritative patient education resources from MD Anderson Cancer Center and an AI recovery coach powered by a small language model that analyzes recent recovery signals to generate personalized trend summaries and recovery guidance. Together, these components provide a standardized, intelligent, and adaptive platform for post-thyroidectomy rehabilitation.

### Demo Video
<!--
Add the public link to your YouTube or video posted elsewhere.
-->
To learn more about this application, watch the video below:

<a href="https://youtu.be/qLOPrCSr2uc" target="_blank"><img width="320" height="180" alt="mq1" src="https://github.com/user-attachments/assets/46215a27-7cf8-4183-a802-615165f5f672" /></a>





### Designed for the following users
<!--
Describe the types of users your app is designed for and who will benefit from your app.
-->
The app is designed to support individuals recovering from thyroid cancer surgery during the post-surgery aftercare and rehabilitation. Many patients face challenges such as managing medications, monitoring symptoms, and understanding their recovery. This application helps users track their daily and weekly symptoms, generate visual charts to monitor progress, and receive guidance on the next steps in their rehabilitation, making it easier to stay informed and actively manage their health.
<!--
In addition, you can drop screenshots directly into your README file to add them to your README. Take these from your presentations.
-->
- Login and Sign Up Page
<img width="279" height="304" alt="image" src="https://github.com/user-attachments/assets/25a908e4-b6ce-4e6c-84cc-17d64a570f0d" />

- Onboarding Page
<img width="1352" height="582" alt="image" src="https://github.com/user-attachments/assets/345cb9c6-52ad-410e-840c-b8f0ab70a924" />

- Home Page
<img width="959" height="308" alt="image" src="https://github.com/user-attachments/assets/c70038fd-0602-4e41-b354-cafda0db182d" />

- Insight Data Display
<img width="137" height="289" alt="image" src="https://github.com/user-attachments/assets/bd8cb05d-7bb9-48ca-ba18-5cea882db6e7" />

- Key Features:
1. Daily and Weekly Survey
<img width="697" height="295" alt="image" src="https://github.com/user-attachments/assets/ed8c9c0a-9d80-44ff-8c65-29a17b319c84" />

2. 3D Education Model
<img width="281" height="152" alt="image" src="https://github.com/user-attachments/assets/9ce3e8c0-1131-43ad-9019-a5c44741bdb5" />

3. Recover Note
<img width="236" height="257" alt="image" src="https://github.com/user-attachments/assets/a013c64a-9a86-4246-8f6f-72e6843e2ac3" />

4. Comfort Score
<img width="392" height="285" alt="image" src="https://github.com/user-attachments/assets/bfa90df9-6deb-4a82-b72f-875414738ccb" />

5. Small Language Model (SLM) Suggestions
<img width="897" height="239" alt="image" src="https://github.com/user-attachments/assets/746839cd-fb9f-4161-b5f0-6ed1e75b56b9" />

The SLM took at least 3 days of data(as shown above) to analyze patients'  recovery treatment  and give suggestions as shown below

<img width="169" height="352" alt="image" src="https://github.com/user-attachments/assets/1d6ee407-4c31-4d78-85cd-90213237a13d" />


<!--
List all of the members who developed the project and
link to each members respective GitHub profile
-->

Developed by: 
- [Yuxin Xu](https://github.com/Shoma-xyl) - `University of Southern California`, `Computer Engineering`
- [Ruizhe Zhou](https://github.com/ruizhe-usc) - `University of Southern California`, `Electrical Engineering`
  
ParseCareKit synchronizes the following entities to Parse tables/classes using [Parse-Swift](https://github.com/parse-community/Parse-Swift):

- [x] OCKTask <-> Task
- [x] OCKHealthKitTask <-> HealthKitTask 
- [x] OCKOutcome <-> Outcome
- [x] OCKRevisionRecord.KnowledgeVector <-> Clock
- [x] OCKPatient <-> Patient
- [x] OCKCarePlan <-> CarePlan
- [x] OCKContact <-> Contact

**Use at your own risk. There is no promise that this is HIPAA compliant and we are not responsible for any mishandling of your data**

<!--
What features were added by you, this should be descriptions of features added from the [Code](https://uk.instructure.com/courses/2030626/assignments/11151475) and [Demo](https://uk.instructure.com/courses/2030626/assignments/11151413) parts of the final. Feel free to add any figures that may help describe a feature. Note that there should be information here about how the OCKTask/OCKHealthTask's and OCKCarePlan's you added pertain to your app.
-->
## Contributions/Features

- Custom onboarding task using ResearchKit, including welcome step, consent/signature page, permission request, and completion flow.
- Add onboarding that users must finish before the rest of the Care page tasks are shown.
- Add Range of Motion and Neck Mobility custom CareKit tasks that launch ResearchKit active tasks and record device motion to neck check.
- Add daily symptom tracking and weekly evaluation survey tasks for thyroid recovery, and display the answer
- Add iOS Contacts import using `CNContactPickerViewController`, converting `CNContact` into `OCKContact`, and a searchable Contact page using `UISearchController`.
- Added Profile editing for patient and contact/address information using a ViewModel-based structure.
- Added custom task creation and task deletion from the Profile page.
- Added HealthKit-backed task creation support for data like step count and resting heart rate.
- Added Thyroid 3D Model education task using `Thyroid.usdz`, `ORKUSDZModelManager`, and `ORK3DModelStep`.
- Added AI Recovery Advice tab that builds recent recovery summaries from CareKit data and calls a local Ollama model, `thyro-qwen3`.
- Added thyroid recovery-specific UI content such as voice recovery tips, recovery resource links, and post-surgery-focused task instructions.

## Final Checklist
<!--
This is from the checkist from the final [Code](https://uk.instructure.com/courses/2030626/assignments/11151475). You should mark completed items with an x and leave non-completed items empty
-->
- [x] Signup/Login screen tailored to app
- [x] Signup/Login with email address
- [x] Custom app logo
- [x] Custom styling
- [x] Add at least **5 new OCKTask/OCKHealthKitTasks** to your app
  - [x] Have a minimum of 7 OCKTask/OCKHealthKitTasks in your app
  - [x] 3/7 of OCKTasks should have different OCKSchedules than what's in the original app
- [x] Use at least 5/7 card below in your app
  - [x] InstructionsTaskView - typically used with a OCKTask
  - [x] SimpleTaskView - typically used with a OCKTask
  - [x] Checklist - typically used with a OCKTask
  - [x] Button Log - typically used with a OCKTask
  - [x] GridTaskView - typically used with a OCKTask
  - [x] NumericProgressTaskView (SwiftUI) - typically used with a OCKHealthKitTask
  - [x] LabeledValueTaskView (SwiftUI) - typically used with a OCKHealthKitTask
- [x] Add the LinkView (SwiftUI) card to your app
- [x] Replace the current TipView with a class with CustomFeaturedContentView that subclasses OCKFeaturedContentView. This card should have an initializer which takes any link
- [x] Tailor the ResearchKit Onboarding to reflect your application
- [x] Add tailored check-in ResearchKit survey to your app
- [x] Add a new tab called "Insights" to MainTabView
- [x] Replace current ContactView with Searchable contact view
- [x] Change the ProfileView to use a Form view
- [x] Add at least two OCKCarePlan's and tie them to their respective OCKTask's and OCContact's 

## Wishlist features
<!--
Describe at least 3 features you want to add in the future before releasing your app in the app-store
-->
1. We hope we can improve our 3D module. In the future, we want to integrate this feature with the hospital's current medical image system, allowing doctors to directly send patients' thyroid 3D models to the application. In this way, patients can understand why and how their surgery operation goes, which helps patients have more confidence and focus on rehabilitation. 
2. Currently, the SLM inference runs on a local server, which requires the patient and the server to be on the same network. In the future, we plan to deploy the fine-tuned model to a HIPAA-compliant cloud inference endpoint, enabling real-device usage without any local infrastructure. This would make ThyroRecover accessible to patients anywhere, at any time, while keeping patient data encrypted in transit and never shared with third-party AI services.
3. The current model is fine-tuned on 1,000 synthetic patient records. In the future, we hope to collaborate with clinical partners to collect real, anonymized post-thyroidectomy recovery data and retrain the model. A clinically grounded training set would improve the accuracy and reliability of the model's trend assessments and recommendations, bringing the system closer to clinical-grade personalized guidance.

## Challenges faced while developing
<!--
-->
Learning Swift and integrating a fine-tuned Small Language Model into a CareKit-based application presented several challenges. The baseline app was built on Apple's OCKSample, which required significant time to understand due to its strict data model and Swift 6 concurrency requirements. The most significant challenge was deploying the fine-tuned Qwen3-4B model on device. Core ML's conversion toolchain does not yet stably support the Qwen3 architecture, and adding llama.cpp as a Swift Package caused dependency conflicts with existing frameworks. We resolved this by adopting a local inference server using Ollama. An additional issue was Qwen3's built-in thinking mode, which caused inference timeouts by generating lengthy internal reasoning before producing output. We overcame this by customizing the model's prompt template to suppress thinking mode, reducing response time to under thirty seconds. Finally, the SLM trigger logic required iteration, as early versions based on post-operative day count proved unreliable for new users, and we revised it to check for actual recovery data presence instead.

## Setup Your Parse Server

### Heroku
The easiest way to setup your server is using the [one-button-click](https://github.com/netreconlab/parse-hipaa#heroku) deplyment method for [parse-hipaa](https://github.com/netreconlab/parse-hipaa).


## View your data in Parse Dashboard

### Heroku
The easiest way to setup your dashboard is using the [one-button-click](https://github.com/netreconlab/parse-hipaa-dashboard#heroku) deplyment method for [parse-hipaa-dashboard](https://github.com/netreconlab/parse-hipaa-dashboard).

