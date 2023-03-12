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
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBaseAvatars%2FBear(1).png?alt=media&token=3003a6f9-4f7e-4754-b051-b1c30f2fa87e"
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
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBaseAvatars%2FBunny(1).png?alt=media&token=6b999463-498d-45c7-8ef2-a91dc4cea943"
            }

        case .Cow:
            switch item {
            case .CatEyeShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FCow%2FGroup%2022372.png?alt=media&token=1d999bac-6953-4ebb-805b-c656a83f9d52"
            case .HardoShades:
                return
                "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FCow%2FGroup%2022370.png?alt=media&token=b486e37b-c713-482b-8566-be03fedc6003"
            case .HeartShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FCow%2FGroup%2022367.png?alt=media&token=c6e73276-e1d2-4d3c-aa4a-c4cc9d4bfb96"
            case .LennonShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FCow%2FGroup%2022373.png?alt=media&token=e1998468-4d64-495d-86c5-08ee0f26e8fe"
            case .ScubaShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FCow%2FGroup%2022369.png?alt=media&token=eedebd78-faab-4893-8144-6c29ffd1b32b"
            case .SpikeyShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FCow%2FGroup%2022371.png?alt=media&token=63b43024-f9dc-4bc9-af41-5c436e2c732a"
            default:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBaseAvatars%2FCow(1).png?alt=media&token=5b53ce80-a9d6-4fba-9f34-0082e79cfd33"
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
                return
                "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FDeer%2FGroup%2022408.png?alt=media&token=7d6f1710-6b9e-4e25-b7ee-9f44fb43ba15"
            case .ScubaShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FDeer%2FGroup%2022404.png?alt=media&token=3ed29eba-d825-4b7c-ad27-71f32e52a14d"
            case .SpikeyShades:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FDeer%2FGroup%2022406.png?alt=media&token=3c9951dd-50ec-433d-8bf1-6385135c30b1"
            default:
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBaseAvatars%2FDeer(1).png?alt=media&token=0bb6be17-edbe-4387-adcd-03e3fb1a78d2"
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
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBaseAvatars%2FElephant(1).png?alt=media&token=7e79ba1e-e5ad-4830-a23d-8327b6dcf14e"
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
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBaseAvatars%2FGiraffe(1).png?alt=media&token=9df2a0d8-8781-45fd-9b85-0484baf30d93"
            }

        case .Lion:
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
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBaseAvatars%2FLion(1).png?alt=media&token=01cd3ce4-bdc9-4286-a2cb-9b37da5062cd"
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
                return                 "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBaseAvatars%2FMonkey(1).png?alt=media&token=1d88e065-6223-47bc-b933-356ed1d36971"
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
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBaseAvatars%2FPanda(1).png?alt=media&token=c1dab844-0b9f-441d-b9cb-63093a0a2935"
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
                return "https://firebasestorage.googleapis.com/v0/b/sp0t-app.appspot.com/o/spotPics-dev%2F0000000croppedAnimals%2FBaseAvatars%2FPig(1).png?alt=media&token=6bc2dd12-e31f-4d50-b611-a4e3ff5bdf35"
            }
        }
    }
}
