<!--
Name of your final project
-->
# ThyroRecover
![Swift](https://img.shields.io/badge/swift-5.5-brightgreen.svg) ![Xcode 13.2+](https://img.shields.io/badge/xcode-13.2%2B-blue.svg) ![iOS 15.0+](https://img.shields.io/badge/iOS-15.0%2B-blue.svg) ![watchOS 8.0+](https://img.shields.io/badge/watchOS-8.0%2B-blue.svg) ![CareKit 2.1+](https://img.shields.io/badge/CareKit-2.1%2B-red.svg) ![ci](https://github.com/netreconlab/CareKitSample-ParseCareKit/workflows/ci/badge.svg?branch=main)

## Description
<!--
Give a short description of what your project accomplishes and what tools it uses. Basically, what problems does it solve and why is it different from other apps in the app store?
-->
The five-year survival rate of thyroid cancer exceeds $97\%$, but long-term self-management after thyroidectomy remains critical for preventing complications and recurrence. However, existing mobile health applications for post-thyroidectomy rehabilitation lack targeted multidimensional support, particularly in personalized symptom tracking, intelligent follow-up scheduling, and psychological assistance. These gaps lead to significant deficiencies in out-of-hospital management, including suboptimal patient adherence, fragmented clinician-patient communication, and a scarcity of standardized self-management tools. 
To address these challenges, we propose ThyroRecover, a specialized iOS rehabilitation application built on Apple’s open-source CareKit framework. Based on the OCKSample project, ThyroRecover provides ERAS-aligned recovery tasks, including tracking voice and swallowing discomfort, setting early ambulation goals, hydration reminders, and structured daily check-ins. The system further integrates ResearchKit to support thyroid anatomy education, neck range-of-motion assessment, and structured symptom surveys, while SwiftUI Charts are used to present multidimensional recovery trends. In addition, ThyroRecover incorporates authoritative patient education resources from MD Anderson Cancer Center and an AI recovery coach powered by a small language model that analyzes recent recovery signals to generate personalized trend summaries and recovery guidance. Together, these components provide a standardized, intelligent, and adaptive platform for post-thyroidectomy rehabilitation.

### Demo Video
<!--
Add the public link to your YouTube or video posted elsewhere.
-->
To learn more about this application, watch the video below:

<a href="http://www.youtube.com/watch?feature=player_embedded&v=mib_YioKAQQ
" target="_blank"><img src="http://img.youtube.com/vi/mib_YioKAQQ/0.jpg" 
alt="Sample demo video" width="240" height="180" border="10" /></a>

### Designed for the following users
<!--
Describe the types of users your app is designed for and who will benefit from your app.
-->

<!--
In addition, you can drop screenshots directly into your README file to add them to your README. Take these from your presentations.
-->
<img src="https://user-images.githubusercontent.com/8621344/101721031-06869500-3a75-11eb-9631-88927e9c8f00.png" width="300"> <img src="https://user-images.githubusercontent.com/8621344/101721111-33d34300-3a75-11eb-885e-4a6fc96dbd35.png" width="300"> <img src="https://user-images.githubusercontent.com/8621344/101721146-48afd680-3a75-11eb-955a-7848146a9d6f.png" width="300"><img src="https://user-images.githubusercontent.com/8621344/101721182-5cf3d380-3a75-11eb-99c9-bde40477acf3.png" width="300">

<!--
List all of the members who developed the project and
link to each members respective GitHub profile
-->
Developed by: 
- [Yuxin Xu](https://github.com/Shoma-xyl) - `University of Southern California`, `MAJOR`
- [Ruizhe Zhou](https://github.com/ruizhe-usc) - `University of Southern California`, `MAJOR`
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

## Final Checklist
<!--
This is from the checkist from the final [Code](https://uk.instructure.com/courses/2030626/assignments/11151475). You should mark completed items with an x and leave non-completed items empty
-->
- [x] Signup/Login screen tailored to app
- [x] Signup/Login with email address
- [x] Custom app logo
- [x] Custom styling
- [ x] Add at least **5 new OCKTask/OCKHealthKitTasks** to your app
  - [ x] Have a minimum of 7 OCKTask/OCKHealthKitTasks in your app
  - [ x] 3/7 of OCKTasks should have different OCKSchedules than what's in the original app
- [ x] Use at least 5/7 card below in your app
  - [ x] InstructionsTaskView - typically used with a OCKTask
  - [ ] SimpleTaskView - typically used with a OCKTask
  - [ ] Checklist - typically used with a OCKTask
  - [ ] Button Log - typically used with a OCKTask
  - [ ] GridTaskView - typically used with a OCKTask
  - [x ] NumericProgressTaskView (SwiftUI) - typically used with a OCKHealthKitTask
  - [ x] LabeledValueTaskView (SwiftUI) - typically used with a OCKHealthKitTask
- [x] Add the LinkView (SwiftUI) card to your app
- [x ] Replace the current TipView with a class with CustomFeaturedContentView that subclasses OCKFeaturedContentView. This card should have an initializer which takes any link
- [x ] Tailor the ResearchKit Onboarding to reflect your application
- [ x] Add tailored check-in ResearchKit survey to your app
- [ x] Add a new tab called "Insights" to MainTabView
- [x ] Replace current ContactView with Searchable contact view
- [ x] Change the ProfileView to use a Form view
- [ x] Add at least two OCKCarePlan's and tie them to their respective OCKTask's and OCContact's 

## Wishlist features
<!--
Describe at least 3 features you want to add in the future before releasing your app in the app-store
-->
1. We hope we can improve our 3D module. In the future, we want to integrate this feature with the hospital's current medical image system, allowing doctors to directly send patients' thyroid 3D models to the application. In this way, patients can understand why and how their surgery operation goes, which helps patients have more confidence and focus on rehabilitation. 
2. feature two
3. feature three

## Challenges faced while developing
<!--
Describe any challenges you faced with learning Swift, your baseline app, or adding features. You can describe how you overcame them.
-->

## Setup Your Parse Server

### Heroku
The easiest way to setup your server is using the [one-button-click](https://github.com/netreconlab/parse-hipaa#heroku) deplyment method for [parse-hipaa](https://github.com/netreconlab/parse-hipaa).


## View your data in Parse Dashboard

### Heroku
The easiest way to setup your dashboard is using the [one-button-click](https://github.com/netreconlab/parse-hipaa-dashboard#heroku) deplyment method for [parse-hipaa-dashboard](https://github.com/netreconlab/parse-hipaa-dashboard).

