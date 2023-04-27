//
//  AvatarURLs.swift
//  Spot
//
//  Created by Kenny Barone on 3/10/23.
//  Copyright © 2023 sp0t, LLC. All rights reserved.
//

import Foundation
extension AvatarProfile {
    func getURL() -> String {
        switch family {
        case .Bear:
            switch item {
            case .CatEyeShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBear%2FGroup%2022293.png?alt=media&token=23954140-1315-474f-8b3a-b689716d005d"
            case .HardoShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBear%2FGroup%2022346.png?alt=media&token=9bfed84f-2ee2-4307-a14c-a5d6d84511b4"
            case .HeartShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBear%2FGroup%2022306.png?alt=media&token=c535a582-3794-41bd-a2e1-252e9d659c07"
            case .LennonShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBear%2FGroup%2022360.png?alt=media&token=23a421db-ffbd-4a5c-982a-3963af10fa93"
            case .ScubaShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBear%2FGroup%2022298.png?alt=media&token=98be2bbb-818f-436d-af0a-1062802f3813"
            case .SpikeyShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBear%2FGroup%2022278.png?alt=media&token=5cdf09bf-a200-4b2e-b30a-3bfa85a88f79"
            default:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBaseAvatars%2FBear(2).png?alt=media&token=cce7a0bd-cf47-4c3e-9aaa-2037e825c39c"
            }

        case .Bunny:
            switch item {
            case .CatEyeShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBunny%2FGroup%2022377.png?alt=media&token=82427c90-ef57-4386-b03d-e38701787201"
            case .HardoShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBunny%2FGroup%2022375.png?alt=media&token=1712b9e5-d171-472a-8b29-82c4f7ba7f35"
            case .HeartShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBunny%2FGroup%2022368.png?alt=media&token=51d82333-3264-4092-a3a4-776f6e727e93"
            case .LennonShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBunny%2FGroup%2022378.png?alt=media&token=f810cc6d-a7a0-4f8c-8e50-e884666ee436"
            case .ScubaShades:
                return  "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBunny%2FGroup%2022374.png?alt=media&token=7d849335-0f8e-4caa-a17b-7eba01f7e750"
            case .SpikeyShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBunny%2FGroup%2022376.png?alt=media&token=423e5794-33e6-4eaf-b3e3-a184d738309f"
            default:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBaseAvatars%2FBunny(2).png?alt=media&token=44f95521-d652-4a21-b2f7-9662f237a9bf"
            }

        case .Cow:
            switch item {
            case .CatEyeShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FCow%2FGroup%2022372.png?alt=media&token=1d999bac-6953-4ebb-805b-c656a83f9d52"
            case .HardoShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FCow%2FGroup%2022370.png?alt=media&token=b486e37b-c713-482b-8566-be03fedc6003"
            case .HeartShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FCow%2FGroup%2022367.png?alt=media&token=c6e73276-e1d2-4d3c-aa4a-c4cc9d4bfb96"
            case .LennonShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FCow%2FGroup%2022373.png?alt=media&token=e1998468-4d64-495d-86c5-08ee0f26e8fe"
            case .ScubaShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FCow%2FGroup%2022369.png?alt=media&token=eedebd78-faab-4893-8144-6c29ffd1b32b"
            case .SpikeyShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FCow%2FGroup%2022371.png?alt=media&token=63b43024-f9dc-4bc9-af41-5c436e2c732a"
            default:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBaseAvatars%2FCow(2).png?alt=media&token=8feaf59a-75f4-4ed1-955c-c11cd4b95441"
            }

        case .Deer:
            switch item {
            case .CatEyeShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FDeer%2FGroup%2022407.png?alt=media&token=553b7414-ff7c-404a-a961-70341b7269b3"
            case .HardoShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FDeer%2FGroup%2022405.png?alt=media&token=4a32eb08-3c3f-4efa-b535-3ce32a353f99"
            case .HeartShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FDeer%2FGroup%2022403.png?alt=media&token=2a10a968-de57-4d83-9f05-c47caa768fd3"
            case .LennonShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FDeer%2FGroup%2022408.png?alt=media&token=7d6f1710-6b9e-4e25-b7ee-9f44fb43ba15"
            case .ScubaShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FDeer%2FGroup%2022404.png?alt=media&token=3ed29eba-d825-4b7c-ad27-71f32e52a14d"
            case .SpikeyShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FDeer%2FGroup%2022406.png?alt=media&token=3c9951dd-50ec-433d-8bf1-6385135c30b1"
            default:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBaseAvatars%2FDeer(2).png?alt=media&token=8dda3986-6be3-4c0f-bed7-5833c4b23fc5"
            }

        case .Elephant:
            switch item {
            case .CatEyeShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FElephant%2FGroup%2022398.png?alt=media&token=b5a13cbe-b38f-4851-b63c-74c5227e29d5"
            case .HardoShades:
                return  "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FElephant%2FGroup%2022400.png?alt=media&token=fc9d0199-2a26-44cd-8524-d09a3637c3c7"
            case .HeartShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FElephant%2FGroup%2022402.png?alt=media&token=e4ec11ce-8486-49f7-b73f-fc36f6b2de56"
            case .LennonShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FElephant%2FGroup%2022397.png?alt=media&token=485ed26f-688e-4075-9567-6c36a2fd4ced"
            case .ScubaShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FElephant%2FGroup%2022401.png?alt=media&token=adfa419c-c264-4653-9170-bd0fd4367807"
            case .SpikeyShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FElephant%2FGroup%2022399.png?alt=media&token=2e62895c-303b-43a7-97cb-b2734eb8e3bb"
            default:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBaseAvatars%2FElephant(2).png?alt=media&token=ea483349-75a2-462c-abc9-4725615b31fb"
            }

        case .Giraffe:
            switch item {
            case .CatEyeShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FGiraffe%2FGroup%2022410.png?alt=media&token=b00526a3-287b-46eb-a3bb-aab3a29cc6bc"
            case .HardoShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FGiraffe%2FGroup%2022412.png?alt=media&token=93461fe6-a80c-45bd-9ff1-7f9e8f62e9bd"
            case .HeartShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FGiraffe%2FGroup%2022414.png?alt=media&token=2faee6d5-13b0-4f4f-9cd6-cc2d594592a6"
            case .LennonShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FGiraffe%2FGroup%2022409.png?alt=media&token=a436cce6-627a-4927-873d-a0cc6d4890b5"
            case .ScubaShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FGiraffe%2FGroup%2022413.png?alt=media&token=2c3d2aa2-4c32-46df-99cb-2fcd21861e9a"
            case .SpikeyShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FGiraffe%2FGroup%2022411.png?alt=media&token=3632d767-80ea-4e36-9302-0a02255babc6"
            default:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBaseAvatars%2FGiraffe(2).png?alt=media&token=498c0d8e-2d90-4480-9b37-412f665d593a"
            }

        case .Lion:
            switch item {
            case .CatEyeShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FLion%2FGroup%2022380.png?alt=media&token=fed48e6c-d4f2-4484-806e-812d733a34f5"
            case .HardoShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FLion%2FGroup%2022382.png?alt=media&token=64143efb-b0f2-4bba-aac1-ca732742d0c2"
            case .HeartShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FLion%2FGroup%2022384.png?alt=media&token=e6000ca7-ce4b-445f-adb1-6b8f1e07a1ff"
            case .LennonShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FLion%2FGroup%2022379.png?alt=media&token=79ce53b3-2b3d-4dc5-b396-a9e6fad0ae37"
            case .ScubaShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FLion%2FGroup%2022383.png?alt=media&token=9c27caaa-9602-400c-bb13-afc511194bed"
            case .SpikeyShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FLion%2FGroup%2022381.png?alt=media&token=f26073fc-a441-4700-bf49-7621efa99f5b"
            default:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBaseAvatars%2FLion(2).png?alt=media&token=f7e1b700-ef8a-4f0c-ab66-9315f70491ed"
            }

        case .Monkey:
            switch item {
            case .CatEyeShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FMonkey%2FGroup%2022386.png?alt=media&token=f3e0cbc9-bebf-48e4-89df-1659d40af9b3"
            case .HardoShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FMonkey%2FGroup%2022388.png?alt=media&token=40360394-c11d-4630-8bff-a7ae957ba7e2"
            case .HeartShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FMonkey%2FGroup%2022390.png?alt=media&token=c5ea3751-b613-40d0-ae41-7225997ceead"
            case .LennonShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FMonkey%2FGroup%2022385.png?alt=media&token=0250af20-418c-47d3-8741-6cefac4f7eca"
            case .ScubaShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FMonkey%2FGroup%2022389.png?alt=media&token=04678453-0a92-4f24-abe0-b57f283c55c7"
            case .SpikeyShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FMonkey%2FGroup%2022387.png?alt=media&token=384cfcaa-ef17-4986-9697-3b8530f04fc0"
            default:
                return                 "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBaseAvatars%2FMonkey(2).png?alt=media&token=1efdf0f5-cf59-427a-8661-eb8be6b2dee2"
            }

        case .Panda:
            switch item {
            case .CatEyeShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FPanda%2FGroup%2022395.png?alt=media&token=dbb08a5d-82fb-4801-b204-a8016511687f"
            case .HardoShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FPanda%2FGroup%2022393.png?alt=media&token=b24c5499-f035-41ec-a45c-f27a5da9331b"
            case .HeartShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FPanda%2FGroup%2022391.png?alt=media&token=7ad46c57-fcbb-4e70-8518-29825b582138"
            case .LennonShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FPanda%2FGroup%2022396.png?alt=media&token=2ed4b6cf-074f-4374-a149-3e5780b1d2a3"
            case .ScubaShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FPanda%2FGroup%2022392.png?alt=media&token=5096bbeb-87e7-4948-a4be-c24005b6569a"
            case .SpikeyShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FPanda%2FGroup%2022394.png?alt=media&token=50f300c0-37fe-4018-9b31-b43331868592"
            default:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBaseAvatars%2FPanda(3).png?alt=media&token=2bbf0743-d64f-414c-967e-25bb7e73465e"
            }

        case .Pig:
            switch item {
            case .CatEyeShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FPig%2FGroup%2022301.png?alt=media&token=3ad59566-8897-46da-9bda-7bffcd2630ec"
            case .HardoShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FPig%2FGroup%2022303.png?alt=media&token=fd9efa26-5a71-4acf-975b-86b8784eb882"
            case .HeartShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FPig%2FGroup%2022305.png?alt=media&token=1708cf58-4139-4250-9e51-6300d9f7b74c"
            case .LennonShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FPig%2FGroup%2022362.png?alt=media&token=37d5f565-24a8-498a-94f2-28a8e9ca62fd"
            case .ScubaShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FPig%2FGroup%2022304.png?alt=media&token=d18ffb2b-5b81-4eac-a473-60c531013e09"
            case .SpikeyShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FPig%2FGroup%2022302.png?alt=media&token=dfe39f08-9db3-4df2-a45d-0a9594bcc1e3"
            default:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBaseAvatars%2FPig(2).png?alt=media&token=cd8cb003-687b-4b66-b472-661c53342650"
            }
            // MARK: unlockables
        case .Croc:
            switch item {
            case .CatEyeShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FCroc%2FGroup%2022501.png?alt=media&token=80fd789a-29f4-46ad-b59c-f64262fcb360"
            case .HardoShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FCroc%2FGroup%2022503.png?alt=media&token=3b73b8a6-eba8-43ca-9e9f-1b62088767ff"
            case .HeartShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FCroc%2FGroup%2022505.png?alt=media&token=799ed478-f285-46a2-9633-ea136d217420"
            case .LennonShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FCroc%2FGroup%2022500.png?alt=media&token=2e09f069-471f-4b05-9758-ab997abeadac"
            case .ScubaShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FCroc%2FGroup%2022504.png?alt=media&token=c3c455f5-a000-4b23-a9fc-eaddc9b298fa"
            case .SpikeyShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FCroc%2FGroup%2022502.png?alt=media&token=61fa0f79-436f-4cc3-9c48-f8d14ded7501"
            default:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBaseAvatars%2Fcroc.png?alt=media&token=6adf6f25-7803-46aa-9adf-ae7915f2c457"
            }
        case .Chicken:
            switch item {
                // all switch cases
            case .CatEyeShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FChicken%2FGroup%2022507.png?alt=media&token=8a5a0357-5a8e-4898-be06-d098a9350530"
            case .HardoShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FChicken%2FGroup%2022508.png?alt=media&token=8a26bd65-cc7c-42c2-ae93-44fb8bababa9"
            case .HeartShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FChicken%2FGroup%2022511.png?alt=media&token=2a81150c-648d-408b-adda-d209dcf54939"
            case .LennonShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FChicken%2FGroup%2022506.png?alt=media&token=ab35a989-5508-45d3-98a3-f27d3aee2f23"
            case .ScubaShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FChicken%2FGroup%2022510.png?alt=media&token=0b4c2480-be33-4bed-9c93-35d9a42ba870"
            case .SpikeyShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FChicken%2FGroup%2022508.png?alt=media&token=8a26bd65-cc7c-42c2-ae93-44fb8bababa9"
            default:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBaseAvatars%2Fchicken.png?alt=media&token=1fa24658-c436-40fd-ad22-ae89eee49190"
            }
        case .Penguin:
            switch item {
            case .CatEyeShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FPenguin%2Fpenguin(4).png?alt=media&token=618749a1-c373-4804-9032-65ec51ac2db4"
            case .HardoShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FPenguin%2FGroup%2022590.png?alt=media&token=1cadda15-0d1a-4057-a600-6a82ec7c4b58"
            case .HeartShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FPenguin%2FGroup%2022589.png?alt=media&token=92222be5-8280-441d-bb59-d51b3fce41b9"
            case .LennonShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FPenguin%2Fpenguin(3).png?alt=media&token=912e46f4-206c-4bb2-947b-b6570e574d70"
            case .ScubaShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FPenguin%2Fpenguin(7).png?alt=media&token=91f7e482-206e-46b8-bf8b-4d5fb402fab6"
            case .SpikeyShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FPenguin%2Fpenguin(5).png?alt=media&token=50e4a92a-7a31-420a-832c-3539aef82ad2"
            default:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBaseAvatars%2Fpenguin.png?alt=media&token=a2be797b-a706-42e8-9059-329eb118d321"
            }
        case .Cat:
            switch item {
            case .CatEyeShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FCat%2FCat(2).png?alt=media&token=b107a0a8-5a6f-4b19-b4fa-66e5ad407da9:"
            case .HardoShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FCat%2FCat(4).png?alt=media&token=3784968e-2a6c-4dcc-894d-fa0bfd678b0d"
            case .HeartShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FCat%2FCat(6).png?alt=media&token=1a091bda-b32d-49de-8e08-8226f9b32020"
            case .LennonShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FCat%2FCat(1).png?alt=media&token=24b598ad-d27a-4772-b4f8-4a883ab2ea93"
            case .ScubaShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FCat%2FCat(5).png?alt=media&token=07e45d1f-6c72-4af6-9a11-0413e119f5ee"
            case .SpikeyShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FCat%2FCat(3).png?alt=media&token=ffe83f7e-1e3b-4f7f-9b99-5b57ef447c78"
            default:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBaseAvatars%2FCat.png?alt=media&token=ff0ec3bb-47cd-41c7-aa0b-2a3ea74b6d45"
            }
        case .Rhino:
            switch item {
            case .CatEyeShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FRhino%2FRhino(2).png?alt=media&token=bda1643d-9767-42c7-9bb2-049c454262ea"
            case .HardoShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FRhino%2FRhino(4).png?alt=media&token=63aa872a-be55-4d34-b7aa-2d166d5dbf21"
            case .HeartShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FRhino%2FRhino(6).png?alt=media&token=c83e6e6b-0936-4094-b28d-771079651522"
            case .LennonShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FRhino%2FRhino(1).png?alt=media&token=ddb7b205-445c-48ec-952a-404472722691"
            case .ScubaShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FRhino%2FRhino(5).png?alt=media&token=d0c25017-1fd6-4b98-8d2e-cc53827d9493"
            case .SpikeyShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FRhino%2FRhino(3).png?alt=media&token=5dd201bb-3d31-4f64-9375-c06927644c4d"
            default:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBaseAvatars%2FRhino.png?alt=media&token=aad3ce37-d404-4656-a187-db3fbcc7a83c"
            }
        case .Cheetah:
            switch item {
            case .CatEyeShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FCheetah%2FUnicorn(1).png?alt=media&token=2cc19556-6f17-4781-aa96-d4d9a380bae1"
            case .HardoShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FCheetah%2FUnicorn(3).png?alt=media&token=c3cd0892-ee21-42c0-87b5-cfeff4b9942b"
            case .HeartShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FCheetah%2FUnicorn(5).png?alt=media&token=b7275485-3413-4256-b688-8e7a891acdce"
            case .LennonShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FCheetah%2FUnicorn.png?alt=media&token=940d6b7a-ca74-46a9-896d-6804804cace3"
            case .ScubaShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FCheetah%2FUnicorn(4).png?alt=media&token=645e9243-b35b-48fa-925c-88da4db3ced4"
            case .SpikeyShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FCheetah%2FUnicorn(2).png?alt=media&token=6527b770-75a7-4518-88b0-00753cce63b6"
            default:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBaseAvatars%2FCheetah.png?alt=media&token=70686a9a-949b-40ae-857d-77a87d2e7fb7"
            }
        case .PolarBear:
            switch item {
            case .CatEyeShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FPolarBear%2FUnicorn(7).png?alt=media&token=d89b0064-5621-45f4-ab13-1b2767f7f120"
            case .HardoShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FPolarBear%2FUnicorn(9).png?alt=media&token=548c1312-3d90-432b-9406-177e12e1de7e"
            case .HeartShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FPolarBear%2FUnicorn(11).png?alt=media&token=b97f6106-774b-43f9-89e8-92cdd8a144af"
            case .LennonShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FPolarBear%2FUnicorn(6).png?alt=media&token=f48ae1f6-294b-4627-b7e6-50761e3e865e"
            case .ScubaShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FPolarBear%2FUnicorn(10).png?alt=media&token=6853f653-80c5-45ac-887c-3bcb6289e795"
            case .SpikeyShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FPolarBear%2FUnicorn(8).png?alt=media&token=cc17415c-7278-4189-8507-ef9ec64b77ef"
            default:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBaseAvatars%2FPolarBear.png?alt=media&token=37887eda-2c97-4006-b19d-897bc97964de"
            }
        case .Koala:
            switch item {
            case .CatEyeShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FKoala%2FUnicorn(13).png?alt=media&token=00fbf797-e4f6-4d2e-9c2a-c9889bbacce9"
            case .HardoShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FKoala%2FUnicorn(15).png?alt=media&token=2d0eadd8-e33f-4af2-b656-8384402b0880"
            case .HeartShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FKoala%2FUnicorn(17).png?alt=media&token=9009a922-4e87-4948-839b-d5f908ec19fd"
            case .LennonShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FKoala%2FUnicorn(12).png?alt=media&token=89e2e0df-87d5-4985-866e-042057d1d8e0"
            case .ScubaShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FKoala%2FUnicorn(16).png?alt=media&token=00b89d8c-029d-41c5-97b9-214b5d7ab01d"
            case .SpikeyShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FKoala%2FUnicorn(14).png?alt=media&token=9d067963-d761-4595-bee6-b81c129df7f2"
            default:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBaseAvatars%2FKoala.png?alt=media&token=ad7460f3-037f-42b0-97c1-90fba8181561"
            }
        case .Boar:
            switch item {
            case .CatEyeShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBoar%2FUnicorn(19).png?alt=media&token=6d8dac28-a3d2-418e-888d-14b08d43cb0e"
            case .HardoShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBoar%2FUnicorn(21).png?alt=media&token=5261e233-1124-4bc0-8bcc-9bec5da54348"
            case .HeartShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBoar%2FUnicorn(23).png?alt=media&token=5a198d00-eede-414b-830e-d2dd77688437"
            case .LennonShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBoar%2FUnicorn(18).png?alt=media&token=ae915ff9-e4ec-4a5a-86d1-074c3db00bc3"
            case .ScubaShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBoar%2FUnicorn(22).png?alt=media&token=2c5e12ec-e8fb-4fdc-b71c-424b3fffae10"
            case .SpikeyShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBoar%2FUnicorn(20).png?alt=media&token=87e507da-850b-4b0c-84c4-bbf4809eef58"
            default:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBaseAvatars%2FBoar.png?alt=media&token=abd4a8db-bc31-4544-9321-0ef74c2c4626"
            }
        case .Dragon:
            switch item {
            case .CatEyeShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FDragon%2FUnicorn(25).png?alt=media&token=c55fb72f-2b6d-4c82-8f90-22837fb57558"
            case .HardoShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FDragon%2FUnicorn(27).png?alt=media&token=5131bc33-e2da-432a-a26f-c4d40330d3a5"
            case .HeartShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FDragon%2FUnicorn(29).png?alt=media&token=aaf1a4ef-59de-47ec-9d95-daff561b5af0"
            case .LennonShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FDragon%2FUnicorn(24).png?alt=media&token=bde79993-fd81-4cd0-a684-b65e68585ec9"
            case .ScubaShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FDragon%2FUnicorn(28).png?alt=media&token=d1bb0c05-3d52-425d-8678-1c4ca79307fd"
            case .SpikeyShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FDragon%2FUnicorn(26).png?alt=media&token=1cf3354e-9a96-41d1-87e5-d1be18179765"
            default:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBaseAvatars%2FDragon.png?alt=media&token=4c6ea932-573b-4d24-ab92-5edf5487ec3c"
            }
        case .Skunk:
            switch item {
            case .CatEyeShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FSkunk%2FUnicorn(31).png?alt=media&token=9ba11bc3-3910-4a42-9054-25b62b168c4a"
            case .HardoShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FSkunk%2FUnicorn(33).png?alt=media&token=b1939a0a-5d75-4868-929a-4620b0a2dbda"
            case .HeartShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FSkunk%2FUnicorn(35).png?alt=media&token=5ec465c4-034a-48ee-a983-3fcd764446e4"
            case .LennonShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FSkunk%2FUnicorn(30).png?alt=media&token=75f9cee3-30c6-4f42-9f06-8deb008548d2"
            case .ScubaShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FSkunk%2FUnicorn(34).png?alt=media&token=9dd63a50-f022-40ec-8db9-8ac57d300593"
            case .SpikeyShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FSkunk%2FUnicorn(32).png?alt=media&token=331c6011-ef76-4c7b-a5eb-d1ba4ce548ac"
            default:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBaseAvatars%2FOpossum.png?alt=media&token=2e3c399d-fb64-4c84-9e4c-3807bdce687e"
            }
        case .Zebra:
            switch item {
            case .CatEyeShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FZebra%2FUnicorn(37).png?alt=media&token=2ba5c848-d616-43fc-a394-08d75446fc07"
            case .HardoShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FZebra%2FUnicorn(39).png?alt=media&token=b561dc5c-a027-4a11-b048-91b79f4bd801"
            case .HeartShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FZebra%2FUnicorn(41).png?alt=media&token=b0bd2594-488c-4d07-aa1a-52fc0ebbca17"
            case .LennonShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FZebra%2FUnicorn(36).png?alt=media&token=95c15c72-7019-478a-9bb3-0f06456e2328"
            case .ScubaShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FZebra%2FUnicorn(40).png?alt=media&token=357d43de-9061-43f7-b368-07f44979fd1c"
            case .SpikeyShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FZebra%2FUnicorn(38).png?alt=media&token=95416a3e-2398-4bd5-bec4-cc942e016794"
            default: return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBaseAvatars%2FZebra.png?alt=media&token=aa93fe71-af56-41d2-b7cc-505153d65ee6"
            }
        case .Butterfly:
            switch item {
            case .CatEyeShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FButterfly%2FUnicorn(43).png?alt=media&token=d9cc5473-bd4c-49c0-aeaf-6cbb759b4452"
            case .HardoShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FButterfly%2FUnicorn(45).png?alt=media&token=36d2212c-97ae-4f2a-8f80-baefd6a3b595"
            case .HeartShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FButterfly%2FUnicorn(47).png?alt=media&token=59559932-b16b-49a2-8632-8e18a1f4ec29"
            case .LennonShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FButterfly%2FUnicorn(42).png?alt=media&token=d48fd08d-b999-491a-9be4-0b693dc489cf"
            case .ScubaShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FButterfly%2FUnicorn(46).png?alt=media&token=09822dee-d3c3-4017-b18e-051fe82a6201"
            case .SpikeyShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FButterfly%2FUnicorn(44).png?alt=media&token=810e6460-52de-47b0-98c2-ea6ca23938e2"
            default:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBaseAvatars%2FButterfly.png?alt=media&token=24fc2d24-1ba8-4a07-a29d-53819daba6a3"
            }
        case .BlueJay:
            switch item {
            case .CatEyeShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBlueJay%2FUnicorn(49).png?alt=media&token=d2b7c419-3f9b-4f49-8d70-92ba9d28af86"
            case .HardoShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBlueJay%2FUnicorn(51).png?alt=media&token=47e77db1-673c-4ffa-8689-3574c1522802"
            case .HeartShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBlueJay%2FUnicorn(53).png?alt=media&token=49dfd595-57de-44af-8ada-5726443d2a70"
            case .LennonShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBlueJay%2FUnicorn(48).png?alt=media&token=93d48c6e-e6de-4cc4-a5f0-200826b9a253"
            case .ScubaShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBlueJay%2FUnicorn(52).png?alt=media&token=42d96dfe-c6fe-400e-a80d-5e44e8223bf1"
            case .SpikeyShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBlueJay%2FUnicorn(50).png?alt=media&token=0cd2bdd2-0bad-4ad9-9fc7-6123bd1d03b1"
            default: return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBaseAvatars%2FBird.png?alt=media&token=379e87f0-4408-4211-a564-be4ae0a60406"
            }
        case .Bee:
            switch item {
            case .CatEyeShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBee%2FUnicorn(55).png?alt=media&token=a0388026-3552-478d-9ddd-2dad1a624e15"
            case .HardoShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBee%2FUnicorn(57).png?alt=media&token=3a54b264-b723-4c57-ba21-56f2e81bbf8e"
            case .HeartShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBee%2FUnicorn(59).png?alt=media&token=b7fd33cb-12a7-429b-b0d7-71ba5b717231"
            case .LennonShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBee%2FUnicorn(54).png?alt=media&token=944f04d2-e72a-4fa2-9bef-b1ef509b50c6"
            case .ScubaShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBee%2FUnicorn(58).png?alt=media&token=5a1e4f26-b03c-4980-a38d-f90a01a5adb7"
            case .SpikeyShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBee%2FUnicorn(56).png?alt=media&token=d9109cbb-afaf-4923-825a-ff7a09597013"
            default:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBaseAvatars%2FBee.png?alt=media&token=86b29bc3-3705-45b3-822e-9a293cbb79dc"
            }
        case .Unicorn:
            switch item {
            case .CatEyeShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FUnicorn%2FGroup%2022538.png?alt=media&token=e2f99354-7c33-4a1d-8276-1c1f5e263744"
            case .HardoShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FUnicorn%2FGroup%2022540.png?alt=media&token=d0397dcf-86ec-4bb5-bd1c-1a1a9eb73fd3"
            case .HeartShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FUnicorn%2FGroup%2022542.png?alt=media&token=4778da3f-8a77-41b6-ae13-3f0363e4e96c"
            case .LennonShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FUnicorn%2FGroup%2022537.png?alt=media&token=88fdbe38-fe09-474b-9bf6-8aea31e0a02b"
            case .ScubaShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FUnicorn%2FGroup%2022541.png?alt=media&token=9df5a1ee-e564-45d2-9ad5-6aa2085f0fe1"
            case .SpikeyShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FUnicorn%2FGroup%2022539.png?alt=media&token=736d219d-6e95-4efa-88a2-69fa061da23d"
            default:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBaseAvatars%2FUnicorn(60).png?alt=media&token=06646f60-594d-4490-9df8-0c4739ac50c9"
            }
        case .Frog:
            switch item {
            case .CatEyeShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FFrog%2FFrog(2).png?alt=media&token=76402c2a-9d95-451e-885e-7306b22c3746"
            case .HardoShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FFrog%2FFrog(4).png?alt=media&token=ccd04b4e-dcd9-4d02-af7b-c851c6bbd9b0"
            case .HeartShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FFrog%2FFrog(6).png?alt=media&token=766860e3-8c66-4a2d-8258-27caf384fc77"
            case .LennonShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FFrog%2FFrog(1).png?alt=media&token=973bfd3e-8f83-419f-b0d3-a0fe3b827613"
            case .ScubaShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FFrog%2FFrog(5).png?alt=media&token=f807c8ac-485f-4388-bd8f-59fc6f263b37"
            case .SpikeyShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FFrog%2FFrog(3).png?alt=media&token=cb320049-0189-473d-a5fb-1457886cce4e"
            default:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBaseAvatars%2FFrog.png?alt=media&token=800d89b7-39e9-4e8e-94cf-7208da65dd2d"
            }
        case .Jelly:
            switch item {
            case .CatEyeShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FJelly%2FUnicorn(62).png?alt=media&token=221c0cee-97de-4f6d-a824-81bb6bb0f39a"
            case .HardoShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FJelly%2FUnicorn(64).png?alt=media&token=1f7ee80d-b9b7-495e-b521-5ca3c42a06b1"
            case .HeartShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FJelly%2FUnicorn(66).png?alt=media&token=4b37e6b6-5b15-47be-970f-e1049fc7f8f5"
            case .LennonShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FJelly%2FUnicorn(61).png?alt=media&token=2c3ef947-7e3d-4825-b2ab-c107a4576cf0"
            case .ScubaShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FJelly%2FUnicorn(65).png?alt=media&token=a2ff43f3-a372-4214-b69b-946a27fa9cdb"
            case .SpikeyShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FJelly%2FUnicorn(63).png?alt=media&token=36462d30-b641-40ec-bae7-2565dc5cca9c"
            default:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBaseAvatars%2FJelly.png?alt=media&token=2aec058f-1537-45b1-916a-5e6e387bbcaf"
            }
        case .Flower:
            switch item {
            case .CatEyeShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FFlower%2FUnicorn(68).png?alt=media&token=c919db37-6dcd-40d6-be78-6be4e8ddb105"
            case .HardoShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FFlower%2FUnicorn(70).png?alt=media&token=c867e382-f236-4009-ac70-e2b3995d9c23"
            case .HeartShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FFlower%2FUnicorn(72).png?alt=media&token=1638c81d-52ee-4d7f-8180-3d190587e348"
            case .LennonShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FFlower%2FUnicorn(67).png?alt=media&token=683759f3-4274-47cc-9071-94bd3ea24b48"
            case .ScubaShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FFlower%2FUnicorn(71).png?alt=media&token=b6626520-b866-4b1e-87de-2bfba92e9adf"
            case .SpikeyShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FFlower%2FUnicorn(69).png?alt=media&token=bb09c6ac-b603-4fe3-a749-016b5d8e9a9b"
            default:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBaseAvatars%2Fflower.png?alt=media&token=f46cddf2-384e-4b0d-99f3-d9416a27dd9b"
            }
        case .Robot:
            switch item {
            case .CatEyeShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FRobot%2FUnicorn(74).png?alt=media&token=b37ba9b6-12af-4430-a8ed-30db087487eb"
            case .HardoShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FRobot%2FUnicorn(76).png?alt=media&token=63dc3091-c249-45f6-a920-85b94349a7d4"
            case .HeartShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FRobot%2FUnicorn(78).png?alt=media&token=544ce030-0d56-40df-bcba-0b6d5d2e191c"
            case .LennonShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FRobot%2FUnicorn(73).png?alt=media&token=a4738725-8b98-4e04-9bd2-14691a73f8bb"
            case .ScubaShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FRobot%2FUnicorn(77).png?alt=media&token=085c9f31-5399-44ea-a0a4-c6a287f5bc5f"
            case .SpikeyShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FRobot%2FUnicorn(75).png?alt=media&token=4802a51b-f5b7-4b76-82da-ee5b4c820196"
            default:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBaseAvatars%2Fb0t.png?alt=media&token=ed887ffe-73a5-4a60-8cdb-596307720dc2"
            }
        case .Alien:
            switch item {
            case .CatEyeShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FAlien%2FUnicorn(80).png?alt=media&token=e86acade-3e8a-4f7f-8089-b72b5b24d40d"
            case .HardoShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FAlien%2FUnicorn(82).png?alt=media&token=87c5c82a-bf61-47ec-b5d4-fabe82de5ec5"
            case .HeartShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FAlien%2FUnicorn(84).png?alt=media&token=179e3690-f005-4e38-b809-523c420c9d27"
            case .LennonShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FAlien%2FUnicorn(79).png?alt=media&token=527fc9d2-7ef8-49e5-8f56-4caabaf305ed"
            case .ScubaShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FAlien%2FUnicorn(83).png?alt=media&token=f8e5d95d-c46b-4b38-9949-469ea47c3297"
            case .SpikeyShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FAlien%2FUnicorn(81).png?alt=media&token=7ef795e7-d0bb-4e98-b73c-756b37704307"
            default:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBaseAvatars%2FAlien.png?alt=media&token=a28f377b-7f30-4c7b-b171-8a77ffd6e44d"
            }
        }
    }

    func getUnlockScore() -> Int {
        switch family {
        case .Bear, .Bunny, .Cow, .Deer, .Elephant, .Giraffe, .Lion, .Monkey, .Panda, .Pig:
            return 0
        case .Croc:
            return 5
        case .Cat:
            return 25
        case .Rhino:
            return 50
        case .Cheetah:
            return 100
        case .Chicken:
            return 150
        case .Boar:
            return 200
        case .Koala:
            return 250
        case .PolarBear:
            return 300
        case .Dragon:
            return 400
        case .Penguin:
            return 500
        case .Zebra:
            return 600
        case .Skunk:
            return 700
        case .BlueJay:
            return 800
        case .Butterfly:
            return 900
        case .Unicorn:
            return 1000
        case .Bee:
            return 1250
        case .Frog:
            return 1500
        case .Jelly:
            return 2000
        case .Flower:
            return 3000
        case .Robot:
            return 5000
        case .Alien:
            return 10000
        }
    }
}
