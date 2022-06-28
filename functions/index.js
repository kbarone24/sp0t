const admin = require("firebase-admin");
admin.initializeApp();

const functions = require("firebase-functions");
const db = admin.firestore();

exports.runSpotTransactions =
functions.https.onCall(async (request) => {
  const spotID = request.spotID;
  const uid = request.uid;

  const postID = request.postID;
  const postPrivacy = request.postPrivacy;
  const postTag = request.postTag;
  const posters = request.posters;

  const spotRef = db.collection("spots").doc(spotID);

  try {
    await db.runTransaction(async (transaction) => {
     const spotDoc = await transaction.get(spotRef);

      // these 4 are incremented for every post for easy look-ups

      const postIDs = spotDoc.data().postIDs;
      postIDs.push(postID);

      const posterIDs = spotDoc.data().posterIDs;
      posterIDs.push(uid);

      const postPrivacies = spotDoc.data().postPrivacies;
      postPrivacies.push(postPrivacy);

      const postTimestamps = spotDoc.data().postTimestamps;
      const postTimestamp = admin.firestore.Timestamp.fromDate(new Date());
      postTimestamps.push(postTimestamp);

      // visitorList is essentially an arrayUnion func
      const visitorList = spotDoc.data().visitorList;
      for (let i = 0; i < posters.length; i++) {
        // patch fix for "0" getting randomly pushed to array
        if (visitorList.indexOf(posters[i]) == -1 && posters[i] != "0") {
          visitorList.push(posters[i]);
        }
      }

      // if invite only spot, update invite list with new posters
      const inviteList = spotDoc.data().inviteList;
      if (postPrivacy == "invite") {
        for (let i = 0; i < posters.length; i++) {
          // patch fix for "0" getting randomly pushed to array
          if (inviteList.indexOf(posters[i]) == -1 && posters[i] != "0") {
            inviteList.push(posters[i]);
          }
        }
      }

      // increment tags in tagDictionary if theres a tag with the post
      const tagDictionary = spotDoc.data().tagDictionary;
      if (postTag != "") {
        if (tagDictionary[postTag] != undefined) {
          tagDictionary[postTag] += 1;
        } else {
          tagDictionary[postTag] = 1;
        }
      }

      const posterDictionary = spotDoc.data().posterDictionary;
      if (posterDictionary != undefined) {
        posterDictionary[postID] = posters;
      }

      transaction.update(spotRef, {
        posterIDs: posterIDs, postPrivacies: postPrivacies,
        visitorList: visitorList, postIDs: postIDs,
        postTimestamps: postTimestamps, tagDictionary: tagDictionary,
        posterDictionary: posterDictionary, inviteList: inviteList});
    });
    console.log("run spot transactions committed");
    return;
  } catch (e) {
    console.log("run spot transaction failed: ", e);
    return;
  }
});

exports.sendPostNotifications =
functions.firestore.document("posts/{postID}")
    .onCreate((snap, context) => {
      const addedUsers = snap.data().addedUsers;
      const taggedUserIDs = snap.data().taggedUserIDs;
      const inviteList = snap.data().inviteList;
      const isFirst = snap.data().isFirst;
      const posterID = snap.data().posterID;
      const imageURLs = snap.data().imageURLs;
      const postID = context.params.postID;
      const spotID = snap.data().spotID;
      const timestamp = admin.firestore.Timestamp.fromDate(new Date());
      const posterUsername = snap.data().posterUsername;

      let firstURL = "";
      if (imageURLs.length > 0) {
        firstURL = imageURLs[0];
      }

      // should only return for users not on 1.0
      if (addedUsers == undefined || posterUsername == undefined) {
        console.log("no added users");
        return;
      }

      // only want to send one notification per user
      // start with poster ID to not send notis to the current poster
      const userNotiList = [posterID];

      if (isFirst) {
        for (let i = 0; i < inviteList.length; i++) {
          const data = {
            imageURL: firstURL,
            postID: postID,
            seen: false,
            originalPoster: posterUsername,
            senderID: posterID,
            senderUsername: posterUsername,
            spotID: spotID,
            timestamp: timestamp,
            type: "invite",
          };

          db.collection("users").doc(inviteList[i]).
              collection("notifications").add(data);
          userNotiList.push(inviteList[i]);
        }
      }

      for (let i = 0; i < addedUsers.length; i++) {
        // send "added you to post" push + set in notis
        if (userNotiList.indexOf(addedUsers[i]) == -1) {
          const data = {
            imageURL: firstURL,
            postID: postID,
            seen: false,
            originalPoster: posterUsername,
            senderID: posterID,
            senderUsername: posterUsername,
            spotID: spotID,
            timestamp: timestamp,
            type: "postAdd",
          };
          db.collection("users").doc(addedUsers[i])
              .collection("notifications").add(data);
          userNotiList.push(addedUsers[i]);
        }
      }

      if (taggedUserIDs != undefined) {
        for (let i = 0; i < taggedUserIDs.length; i++) {
          // send "mentioned you in a post" push + set in notis
          if (userNotiList.indexOf(taggedUserIDs[i]) == -1) {
            const data = {
              imageURL: firstURL,
              postID: postID,
              seen: false,
              originalPoster: posterUsername,
              senderID: posterID,
              senderUsername: posterUsername,
              spotID: spotID,
              timestamp: timestamp,
              type: "postTag",
            };
            db.collection("users").doc(taggedUserIDs[i])
                .collection("notifications").add(data);
            userNotiList.push(taggedUserIDs[i]);
          }
        }
      }

      // get spotDoc, send noti's to visitors who aren't getting one already
      const spotRef = db.collection("spots").doc(spotID);
      spotRef.get()
          .then((querySnapshot) => {
            if (querySnapshot.exists) {
              const visitorList = querySnapshot.data().visitorList;
              const spotName = querySnapshot.data().spotName;
              for (let i = 0; i < visitorList.length; i++) {
                if (userNotiList.indexOf(visitorList[i]) == -1) {
                  const data = {
                    imageURL: firstURL,
                    postID: postID,
                    seen: false,
                    originalPoster: posterUsername,
                    senderID: posterID,
                    senderUsername: posterUsername,
                    spotID: spotID,
                    timestamp: timestamp,
                    type: "post",
                    spotName: spotName,
                  };
                  db.collection("users").doc(visitorList[i]).
                      collection("notifications").add(data);
                }
              }
            }
          });
    });

exports.addInitialFriends = functions.https.onCall(async (request) => {
  const phone = request.phone;
  const userID = request.userID;
  const username = request.username;

  const initialFriends = ["T4KMLe3XlQaPBJvtZVArqXQvaNT2"];
  let count = 0;
  db.collection("users").where("sentInvites", "array-contains", phone).
      get().then((querySnapshot) => {
        if (querySnapshot.length == 0) {
          sendInitialRequests(userID, username, initialFriends);
          return {initialFriend: false};
        }
        querySnapshot.forEach((doc) => {
          initialFriends.push(doc.id);
          count += 1;
          if (count == querySnapshot.docs.length) {
            sendInitialRequests(userID, username, initialFriends);
            return {initialFriend: true};
          }
        });
      });
});

function sendInitialRequests(userID, username, initialFriends) {
  const topFriends = Object();
  initialFriends.forEach((friend) => {
    topFriends[friend] = 0;
  });

  db.collection("users").doc(userID).update({
    "friendsList": initialFriends,
    "topFriends": topFriends,
  });

  const timestamp = admin.firestore.Timestamp.fromDate(new Date());

  for (let i = 0; i < initialFriends.length; i++) {
    addFriendToFriendsList(initialFriends[i], userID);
    adjustPostFriendsList(userID, initialFriends[i]);
    adjustPostFriendsList(initialFriends[i], userID);

    db.collection("users").doc(userID).collection("notifications").add({
      "status": "accepted",
      "timestamp": timestamp,
      "senderID": initialFriends[i],
      "senderUsername": "",
      "type": "friendRequest",
      "seen": false,
    });

    const invite = (initialFriends[i] == "T4KMLe3XlQaPBJvtZVArqXQvaNT2");
    db.collection("users").doc(initialFriends[i]).
        collection("notifications").add({
          "status": "accepted",
          "timestamp": timestamp,
          "invite": invite,
          "senderID": initialFriends[i],
          "senderUsername": username,
          "type": "friendRequest",
          "seen": false,
        });
  }
}

exports.acceptFriendRequest = functions
    .runWith({
      // Keep 5 instances warm because we want this to go thru quick
      minInstances: 5,
    })
    .https.onCall(async (request) => {
      const userID = request.userID;
      const friendID = request.friendID;
      const username = request.username;
      // add friend to friendsList func for each user

      addFriendToFriendsList(userID, friendID);
      addFriendToFriendsList(friendID, userID);

      adjustPostFriendsList(userID, friendID);
      adjustPostFriendsList(friendID, userID);

      sendFriendRequestNotis(userID, friendID, username);

      return;
    });

async function addFriendToFriendsList(userID, friendID) {
  // add friend to friends list
  // remove friend from pending requests
  const userRef = db.collection("users").doc(userID);

  try {
    await db.runTransaction(async (transaction) => {
      const userDoc = await transaction.get(userRef);

      const friendsList = userDoc.data().friendsList;
      const pendingRequests = userDoc.data().pendingFriendRequests;
      const topFriends = userDoc.data().topFriends;

      if (friendsList.indexOf(friendID) == -1) {
        friendsList.push(friendID);
      }

      const index = pendingRequests.indexOf(friendID);
      if (index != -1) {
        pendingRequests.splice(index, 1);
      }

      topFriends[friendID] = 0;

      transaction.update(userRef, {
        friendsList: friendsList, pendingFriendRequests: pendingRequests,
        topFriends: topFriends});
    });
    console.log("add friend to friends list transaction success");
  } catch (e) {
    console.log("add friend to friends transaction failed: ", e);
  }
}

function adjustPostFriendsList(userID, friendID) {
  // add friend to friendsList for every pub/friends post
  db.collection("posts").where("posterID", "==", userID).
      orderBy("timestamp", "desc").get().then((querySnapshot) => {
        querySnapshot.forEach((doc) => {
          const hideFromFeed = doc.data().hideFromFeed;
          const privacyLevel = doc.data().privacyLevel;
          // these posts won't get added to users feed
          if (hideFromFeed || privacyLevel == "invite") {
            return;
          }
          doc.ref.update({
            friendsList: admin.firestore.FieldValue.arrayUnion(friendID),
          });
          console.log("updated post friendsList", userID, friendID, doc.id);
        });
        console.log("adjusted post friends list success");
      });
}

function sendFriendRequestNotis(userID, friendID, username) {
  const query = db.collection("users").doc(userID).
      collection("notifications").where("senderID", "==", friendID).
      where("type", "==", "friendRequest");
  query.get().then((querySnapshot) => {
    const timestamp = admin.firestore.Timestamp.fromDate(new Date());
    querySnapshot.forEach((doc) => {
      // set noti for current user
      db.collection("users").doc(userID).collection("notifications").
          doc(doc.id).update({
            "status": "accepted",
            "timestamp": timestamp,
          });
      console.log("updated friend request noti", userID, doc.id);
    });
    // set noti for user that sent the request
    db.collection("users").doc(friendID).collection("notifications").add({
      "status": "accepted",
      "timestamp": timestamp,
      "senderID": userID,
      "senderUsername": username,
      "type": "friendRequest",
      "seen": false,
    });
    console.log("send friend request notis success");
  });
}

exports.removeFriendRequest = functions.https.onCall(async (request) => {
  // reject friend request func
  const uid = request.uid;
  const friendID = request.friendID;

  db.collection("users").doc(friendID).update({
    "pendingFriendRequests": admin.firestore.FieldValue.arrayRemove(uid),
  });

  const query = db.collection("users").doc(uid).collection("notifications").
      where("type", "==", "friendRequest").where("senderID", "==", friendID);
  query.get().then((querySnapshot) => {
    querySnapshot.forEach((doc) => {
      doc.ref.delete();
    });
  });
});


exports.removeFriend =
functions.https.onCall(async (request) => {
  const userID = request.userID;
  const friendID = request.friendID;

  removeFriendFromPosts(userID, friendID);
  removeFriendFromPosts(friendID, userID);

  removeFriendFromNotis(userID, friendID);
  removeFriendFromNotis(friendID, userID);

  return;
});

function removeFriendFromPosts(userID, friendID) {
  const query = db.collection("posts").where("posterID", "==", friendID).
      orderBy("timestamp", "desc");
  query.get().then((querySnapshot) => {
    querySnapshot.forEach((doc) => {
      const friendsList = doc.data().friendsList;
      const inviteList = doc.data().inviteList;
      if (friendsList == undefined || inviteList == undefined) {
        return;
      }
      doc.ref.update({
        friendsList: admin.firestore.FieldValue.arrayRemove(userID),
        inviteList: admin.firestore.FieldValue.arrayRemove(userID),
      });
    });
  });
}

function removeFriendFromNotis(userID, friendID) {
  const query = db.collection("users").doc(userID).
      collection("notifications").where("senderID", "==", friendID);
  query.get().then((querySnapshot) => {
    querySnapshot.forEach((doc) => {
      doc.ref.delete();
    });
  });
}

exports.acceptPublicSpot = functions.https.onCall(async (request) => {
  const createdBy = request.createdBy;
  const postPrivacies = request.postPrivacies;
  const posterIDs = request.posterIDs;
  const postIDs = request.postIDs;
  const spotID = request.spotID;

  // return if upload error at some point
  if (postIDs.length != posterIDs.length ||
    postIDs.length != postPrivacies.length) {
    return;
  }

  // if this is an accept public, adjust post privacies for founder
  for (let i = 0; i < posterIDs.length; i++) {
    let privacyLevel = "friends";
    if (posterIDs[i] === createdBy) {
      postPrivacies[i] = "public";
      privacyLevel = "public";
      // update post privacy
    }
    db.collection("posts").doc(postIDs[i]).update({
      "privacyLevel": privacyLevel, "spotPrivacy": "public"});
  }
  db.collection("spots").doc(spotID).update({
    "postPrivacies": postPrivacies});
});

exports.likePost = functions.https.onCall(async (request) => {
  const addedUsers = request.addedUsers;
  const imageURL = request.imageURL;
  const likerUsername = request.username;
  const likerID = request.likerID;
  const postID = request.postID;
  const posterID = request.posterID;
  const posterUsername = request.posterUsername;
  const spotID = request.spotID;
  const timestamp = admin.firestore.Timestamp.fromDate(new Date());

  // don't send noti for self-like
  if (posterID == likerID) {
    return;
  }

  const data = {
    imageURL: imageURL,
    originalPoster: posterUsername,
    postID: postID,
    seen: false,
    senderID: likerID,
    senderUsername: likerUsername,
    spotID: spotID,
    timestamp: timestamp,
    type: "like",
  };

  db.collection("users").doc(posterID).
      collection("notifications").add(data);

  for (let j = 0; j < addedUsers.length; j++) {
    const adderData = {
      imageURL: imageURL,
      originalPoster: posterUsername,
      postID: postID,
      seen: false,
      senderID: likerID,
      senderUsername: likerUsername,
      spotID: spotID,
      timestamp: timestamp,
      type: "likeOnAdd",
    };
    db.collection("users").doc(addedUsers[j]).
        collection("notifications").add(adderData);
  }

  db.collection("users").doc(posterID).
      update({
        "spotScore": admin.firestore.FieldValue.increment(1)});
});

exports.unlikePost = functions.https.onCall(async (request) => {
  const postID = request.postID;
  const posterID = request.posterID;
  const likerID = request.likerID;

  const notificationRef = db.collection("users").
      doc(posterID).collection("notifications");
  const query = notificationRef.
      where("postID", "==", postID).
      where("senderID", "==", likerID).
      where("type", "==", "like");

  query.get().then((querySnapshot) => {
    querySnapshot.forEach((doc) => {
      doc.ref.delete();
      db.collection("users").doc(posterID).update(
          {"spotScore": admin.firestore.FieldValue.increment(-1)});
    });
  });
});

exports.likeComment = functions.https.onCall(async (request) => {
  const commentID = request.commentID;
  const commenterID = request.posterID;
  const imageURL = request.imageURL;
  const likerID = request.likerID;
  const likerUsername = request.likerUsername;
  const postID = request.postID;
  const spotID = request.spotID;
  const posterID = request.posterID;
  const timestamp = admin.firestore.Timestamp.fromDate(new Date());

  if (posterID == likerID) {
    return;
  }

  const data = {
    commentID: commentID,
    imageURL: imageURL,
    postID: postID,
    seen: false,
    senderID: likerID,
    senderUsername: likerUsername,
    spotID: spotID,
    timestamp: timestamp,
    type: "commentLike",
  };

  db.collection("users").doc(commenterID).
      collection("notifications").add(data);
});


exports.unlikeComment = functions.https.onCall(async (request) => {
  const postID = request.postID;
  const commentID = request.commentID;
  const posterID = request.posterID;
  const likerID = request.likerID;

  const notificationRef = db.collection("users").
      doc(posterID).collection("notifications");
  const query = notificationRef.
      where("postID", "==", postID).
      where("senderID", "==", likerID).
      where("commentID", "==", commentID);

  query.get().then((querySnapshot) => {
    querySnapshot.forEach((doc) => {
      doc.ref.delete();
      db.collection("users").doc(posterID).update(
          {"spotScore": admin.firestore.FieldValue.increment(-1)});
    });
  });
});

exports.updateUserList = functions.https.onCall(async (request) => {
  const spotID = request.spotID;
  const newUsers = request.newUsers;
  const oldUsers = request.oldUsers;
  const city = request.city;
  const imageURL = request.imageURL;
  const senderID = request.senderID;
  const senderUsername = request.senderUsername;
  const spotName = request.spotName;

  console.log(spotID);

  newUsers.forEach((userID) => {
    if (userID != senderID) {
      sendInviteNotification(userID, senderID, senderUsername,
          city, imageURL, spotID, spotName);
    }
  });

  oldUsers.forEach((userID) => {
    removeSpotNotification(userID, spotID);
  });

  const spotRef = db.collection("spots").doc(spotID);
  try {
    await db.runTransaction(async (transaction) => {
      const spotDoc = await transaction.get(spotRef);
      const privacyLevel = spotDoc.data().privacyLevel;
      const inviteList = spotDoc.data().inviteList;
      const visitorList = spotDoc.data().visitorList;

      if (privacyLevel == "invite") {
        for (let i = 0; i < newUsers.length; i++) {
          if (inviteList.indexOf(newUsers[i]) == -1) {
            inviteList.push(newUsers[i]);
          }
        }
        for (let i = 0; i < oldUsers.length; i++) {
          const inviteIndex = inviteList.indexOf(oldUsers[i]);
          if (inviteList > -1) {
            inviteList.splice(inviteIndex, 1);
          }
        }
      } else {
        for (let i = 0; i < newUsers.length; i++) {
          if (visitorList.indexOf(newUsers[i]) == -1) {
            visitorList.push(newUsers[i]);
          }
        }
        for (let i = 0; i < oldUsers.length; i++) {
          const visitorIndex = visitorList.indexOf(oldUsers[i]);
          if (visitorIndex > -1) {
            visitorList.splice(visitorIndex, 1);
          }
        }
      }

      transaction.update(spotRef, {
        inviteList: inviteList, visitorList: visitorList});
    });
    console.log("update user list transactions committed");
    return;
  } catch {
    console.log("failed update user list transaction");
  }
});

function sendInviteNotification(userID, senderID,
    senderUsername, city, imageURL, spotID, spotName) {
  const timestamp = admin.firestore.Timestamp.fromDate(new Date());
  // send notification
  const notiData = {
    imageURL: imageURL,
    seen: false,
    senderID: senderID,
    senderUsername: senderUsername,
    spotID: spotID,
    spotName: spotName,
    timestamp: timestamp,
    type: "invite",
  };
  db.collection("users").doc(userID).collection("notifications").add(notiData);

  // add to users spotsList
  const spotData = {
    spotID: spotID,
    checkInTime: timestamp,
    postsList: [],
    city: city,
  };
  db.collection("users").doc(userID).
      collection("spotsList").doc(spotID).set(spotData);
}

function removeSpotNotification(userID, spotID) {
  // delete notifications for this spot
  const query = db.collection("users").doc(userID).collection("notifications").
      where("spotID", "==", spotID);
  query.get().then((snap) => {
    snap.forEach((doc) => {
      doc.ref.delete();
    });
  });
  db.collection("users").doc(userID).collection("spotsList").
      doc(spotID).delete();
}

exports.sendCommentsNotification =
functions.firestore.document("posts/{postID}/comments/{commentID}")
    .onCreate((snap, context) => {
      const postID = context.params.postID;
      const commentID = context.params.commentID;
      const addedUsers = snap.data().addedUsers;
      const commenterID = snap.data().commenterID;
      const commenterUsername = snap.data().commenterUsername;
      const commenterIDList = snap.data().commenterIDList;
      const imageURL = snap.data().imageURL;
      const posterID = snap.data().posterID;
      const posterUsername = snap.data().posterUsername;
      const taggedUserIDs = snap.data().taggedUserIDs;
      const timestamp = admin.firestore.Timestamp.fromDate(new Date());

      // 1.0 check
      if (taggedUserIDs == undefined) {
        return;
      }

      if (commenterIDList.length == 0) {
        return;
      }

      const sentNotiList = [commenterID];

      if (commenterID != posterID) {
        // 1a. send notification to initial poster
        sentNotiList.push(posterID);

        db.collection("users").doc(posterID).update(
            {"spotScore": admin.firestore.FieldValue.increment(1)});
        const type = "comment";
        const data = {
          imageURL: imageURL,
          commentID: commentID,
          originalPoster: posterUsername,
          postID: postID,
          seen: false,
          senderID: commenterID,
          senderUsername: commenterUsername,
          timestamp: timestamp,
          type: type,
        };
        db.collection("users").doc(posterID).
            collection("notifications").add(data);
      }

      // 1b. send notifications to added users
      for (let i = 0; i < addedUsers.length; i++) {
        sentNotiList.push(addedUsers[i]);
        const type = "commentOnAdd";
        const data = {
          imageURL: imageURL,
          commentID: commentID,
          originalPoster: posterUsername,
          postID: postID,
          seen: false,
          senderID: commenterID,
          senderUsername: commenterUsername,
          timestamp: timestamp,
          type: type,
        };
        db.collection("users").doc(addedUsers[i]).
            collection("notifications").add(data);
      }

      // 2. send notifications to anyone tagged in comment
      for (let i = 0; i < taggedUserIDs.length; i++) {
        if (sentNotiList.indexOf(taggedUserIDs[i]) == -1) {
          if (taggedUserIDs[i] != commenterID) {
            sentNotiList.push(taggedUserIDs[i]);
            const type = "commentTag";
            const data = {
              imageURL: imageURL,
              commentID: commentID,
              originalPoster: posterUsername,
              postID: postID,
              seen: false,
              senderID: commenterID,
              senderUsername: commenterUsername,
              timestamp: timestamp,
              type: type,
            };
            db.collection("users").doc(taggedUserIDs[i]).
                collection("notifications").add(data);
          }
        }
      }

      // 3. send notifications to anyone else who commented
      for (let i = 0; i < commenterIDList.length; i++) {
        if (sentNotiList.indexOf(commenterIDList[i]) == -1) {
          sentNotiList.push(commenterIDList[i]);
          const type = "commentComment";
          const data = {
            imageURL: imageURL,
            commentID: commentID,
            originalPoster: posterUsername,
            postID: postID,
            seen: false,
            senderID: commenterID,
            senderUsername: commenterUsername,
            timestamp: timestamp,
            type: type,
          };
          console.log("send to", commenterIDList[i]);
          db.collection("users").doc(commenterIDList[i]).
              collection("notifications").add(data);
        }
      }
      return;
    });

exports.deleteCommentNotification =
    functions.firestore.document("posts/{postID}/comments/{commentID}")
        .onDelete((snap, context) => {
          const addedUsers = snap.data().addedUsers;
          const commentID = context.params.commentID;
          const commenterIDList = snap.data().commenterIDList;
          const posterID = snap.data().posterID;
          const taggedUserIDs = snap.data().taggedUserIDs;

          if (commentID == undefined) {
            return;
          }

          // delete notifications for comment on comment delete
          const sentNotiList = [posterID];
          for (let i = 0; i < commenterIDList.length; i++) {
            if (sentNotiList.indexOf(commenterIDList[i]) == -1) {
              sentNotiList.push(commenterIDList[i]);
            }
          }

          for (let i = 0; i < taggedUserIDs.length; i++) {
            if (sentNotiList.indexOf(taggedUserIDs[i]) == -1) {
              sentNotiList.push(taggedUserIDs[i]);
            }
          }

          for (let i = 0; i < addedUsers.length; i++) {
            if (sentNotiList.indexOf(addedUsers[i]) == -1) {
              sentNotiList.push(addedUsers[i]);
            }
          }

          for (let i = 0; i < sentNotiList.length; i++) {
            const notiRef = db.collection("users").doc(sentNotiList[i]).
                collection("notifications").where("commentID", "==", commentID);
            notiRef.get().then((notiSnap) => {
              notiSnap.forEach((doc) => {
                doc.ref.delete();
              });
            });
          }
          // decrement spotScore
          db.collection("users").doc(posterID).update(
              {"spotScore": admin.firestore.FieldValue.increment(-1)});
        });


exports.sendPushNotification =
functions.firestore.document("users/{userID}/notifications/{notificationID}")
    .onCreate((snap, context) => {
      const userID = context.params.userID;
      const senderUsername = snap.data().senderUsername;
      const type = snap.data().type;
      const status = snap.data().status;
      const spotName = snap.data().spotName;
      const originalPoster = snap.data().originalPoster;
      const invite = snap.data().invite;

      // check for 1.0
      if (senderUsername == undefined || senderUsername == "") {
        return {success: false};
      }
      // get users notification token to send them a push
      console.log("userID", userID);
      const userRef = db.collection("users").doc(userID);
      userRef.get()
          .then((querySnapshot) => {
            if (!querySnapshot.exists) {
              console.log("no snapshot");
              return;
            }
            const token = querySnapshot.data().notificationToken;
            if (token == undefined || token == "") {
              console.log("no token");
              return {success: false};
            }
            const message = getNotificationString(type, status,
                invite, senderUsername, spotName, originalPoster);
            const payload = {
              token: token,
              notification: {
                title: "",
                body: message,
              },
              data: {
                body: message,
              },
            };
            // src: https://engineering.monstar-lab.com/2021/02/09/
            // Use-Firebase-Cloudfunctions-To-Send-Push-Notifications
            admin.messaging().send(payload).then((response) => {
              // Response is a message ID string.
              console.log("Successfully sent message:", response);
              return {success: true};
            }).catch((error) => {
              console.log("error", error.code);
              return {error: error.code};
            });
          });
    });

exports.postDelete =
functions.https.onCall(async (request) => {
  const postIDs = request.postIDs;
  const spotID = request.spotID;
  const uid = request.uid;
  const posters = request.posters;
  const postTag = request.postTag;
  const spotDelete = request.spotDelete;

  const db = admin.firestore();
  let userDelete = false;

  for (let i = 0; i < postIDs.length; i++) {
    const postRef = db.collection("posts").doc(postIDs[i]);
    postRef.collection("comments").get()
        .then((querySnapshot) => {
          if (querySnapshot.empty) {
            postRef.delete();
          }
          // delete all individual comments
          let commentCount = 0;
          querySnapshot.forEach((doc) => {
            doc.ref.delete();
            commentCount += 1;

            // delete postRef once cylced through all comments
            if (commentCount === querySnapshot.size) {
              postRef.delete();
            }
          });
        });

    postNotificationDelete(postIDs[i], spotID);

    if (!spotDelete) {
      // this will always be a singular post
      userDelete = await
      runPostDeleteTransactions(spotID, postIDs[i], postTag, posters, uid);
      return {userDelete: userDelete};
      // runPostDeleteTransactions(spotID, postIDs[i], postTag, posters, uid);
    } else if (i == postIDs.length - 1) {
      const spotRef = db.collection("spots").doc(spotID);
      spotRef.delete();
      userSpotDelete(posters, spotID);
      spotNotificationDelete(posters, spotID);
      return {userDelete: userDelete};
    }
  }
});


function postNotificationDelete(postID, spotID) {
  // get spotDoc, delete notis for this post from all visitors
  const spotRef = db.collection("spots").doc(spotID);
  spotRef.get()
      .then((querySnapshot) => {
        if (querySnapshot.exists) {
          const visitorList = querySnapshot.data().visitorList;
          for (let i = 0; i < visitorList.length; i++) {
            const userNotiRef =
            db.collection("users").doc(visitorList[i]).
                collection("notifications");
            const notiRef = userNotiRef.where("postID", "==", postID);
            notiRef.get().then((querySnapshot) => {
              if (!querySnapshot.empty) {
                querySnapshot.forEach((doc) => {
                  doc.ref.delete();
                });
              }
            });
          }
        }
      });
}

function spotNotificationDelete(posters, spotID) {
  for (let i = 0; i < posters.length; i++) {
    const userNotiRef =
    db.collection("users").doc(posters[i]).collection("notifications");
    const notiRef = userNotiRef.where("spotID", "==", spotID);
    notiRef.get().then((querySnapshot) => {
      if (!querySnapshot.empty) {
        querySnapshot.forEach((doc) => {
          doc.ref.delete();
        });
      }
    });
  }
}

async function
runPostDeleteTransactions(spotID, postID, postTag, posters, uid) {
  const spotRef = db.collection("spots").doc(spotID);
  let userDelete = false;

  try {
    await db.runTransaction(async (transaction) => {
      const spotDoc = await transaction.get(spotRef);

      const postIDs = spotDoc.data().postIDs;
      const posterIDs = spotDoc.data().posterIDs;
      const postPrivacies = spotDoc.data().postPrivacies;
      const postTimestamps = spotDoc.data().postTimestamps;

      const arrayIndex = postIDs.indexOf(postID);

      // need to ensure that posters aren't addedUsers on other posts
      // still issue with if user was added to spot by another user **

      const visitorList = spotDoc.data().visitorList;
      const posterDictionary = spotDoc.data().posterDictionary;

      if (arrayIndex > -1) {
        // delete from posterDictionary (postID for this post is the key)
        delete posterDictionary[postIDs[arrayIndex]];
        const valuesArray = [];
        // get values from dictionary
        const vals = Object.keys(posterDictionary).map(function(key) {
          return posterDictionary[key];
        });
        // get individual users from values ([String])
        for (let i = 0; i < vals.length; i++) {
          const val = vals[i];
          for (let j = 0; j < val.length; j++) {
            valuesArray.push(val[j]);
          }
        }

        for (let i = 0; i < posters.length; i++) {
          const posterIndex = valuesArray.indexOf(posters[i]);
          if (posterIndex > -1) {
            // adjust posters postsList for this spot
            adjustPostsListForSpot(postID, spotID, posters[i]);
          } else {
            const visitorIndex = visitorList.indexOf(posters[i]);
            if (visitorIndex > -1) {
              visitorList.splice(visitorIndex, 1);
              deleteSpotFromSpotsList(spotID, posters[i]);
              if (posters[i] === uid) {
                userDelete = true;
              }
            }
          }

          // decrement tagDictionary for this tag + update sp0tsc0re/topFriends
          // slice(0) copies to avoid pass by reference
          const coPosters = posters.slice(0);
          const idIndex = posters.indexOf(posters[i]);
          if (idIndex > -1) {
            delete coPosters[idIndex];
          }

          decrementUserValues(posters[i], postTag, coPosters);
        }
      }

      // decrement post tag in tagDictionary
      const tagDictionary = spotDoc.data().tagDictionary;
      if (postTag != "") {
        if (tagDictionary[postTag] != undefined) {
          tagDictionary[postTag] -= 1;
        }
      }

      // array index is -1 if value found
      if (arrayIndex > -1) {
        postIDs.splice(arrayIndex, 1);
        posterIDs.splice(arrayIndex, 1);
        postPrivacies.splice(arrayIndex, 1);
        postTimestamps.splice(arrayIndex, 1);
      }

      transaction.update(spotRef, {
        posterIDs: posterIDs, postPrivacies: postPrivacies,
        visitorList: visitorList, postIDs: postIDs,
        postTimestamps: postTimestamps, tagDictionary: tagDictionary,
        posterDictionary: posterDictionary});
    });
    console.log("run post transaction committed");
    return userDelete;
  } catch (e) {
    console.log("run post transaction failed: ", e);
    return;
  }
}

// remove deleted post from spotsList doc for this spot
function adjustPostsListForSpot(postID, spotID, posterID) {
  db.collection("users").doc(posterID).collection("spotsList")
      .doc(spotID).update({
        "postsList": admin.firestore.FieldValue.arrayRemove(postID),
      });
}

function deleteSpotFromSpotsList(spotID, posterID) {
  db.collection("users").doc(posterID).
      collection("spotsList").doc(spotID).delete();
}

async function decrementUserValues(poster, postTag, coPosters) {
  // decrement spotScore here also to keep it to 1 update
  const userRef = db.collection("users").doc(poster);

  try {
    await db.runTransaction(async (transaction) => {
      const userDoc = await transaction.get(userRef);

      let spotScore = userDoc.data().spotScore;
      const tagDictionary = userDoc.data().tagDictionary;
      const topFriends = userDoc.data().topFriends;

      spotScore -= 3;

      if (postTag != "") {
        if (tagDictionary[postTag] != undefined) {
          tagDictionary[postTag] -= 1;
        }
      }

      if (coPosters.length > 0) {
        for (let i = 0; i < coPosters.length; i++) {
          if (topFriends[coPosters[i]] != undefined) {
            topFriends[coPosters[i]] -= 1;
          }
        }
      }

      transaction.update(userRef, {
        spotScore: spotScore, tagDictionary: tagDictionary,
        topFriends: topFriends});
    });
  } catch (e) {
    console.log("user values transaction failed: ", e);
  }
}

function userSpotDelete(posters, spotID) {
  for (let i = 0; i < posters.length; i++) {
    deleteSpotFromSpotsList(spotID, posters[i]);
  }
}

function getNotificationString(type, status, invite,
    senderUsername, spotName, originalPoster) {
  switch (type) {
    case "like":
      return `${senderUsername} liked your post`;
    case "comment":
      return `${senderUsername} commented on your post`;
    case "post":
      return `${senderUsername} posted at ${spotName}`;
    case "invite":
      return `${senderUsername} added you to a spot`;
    case "postAdd":
      return `${senderUsername} added you to a post`;
    case "postTag":
      return `${senderUsername} mentioned you in a post`;
    case "commentTag":
      return `${senderUsername} mentioned you in a comment`;
    case "commentComment":
      return `${senderUsername} commented on ${originalPoster}'s post`;
    case "commentOnAdd":
      return `${senderUsername} commented on ${originalPoster}'s post`;
    case "commentLike":
      return `${senderUsername} liked your comment`;
    case "likeOnAdd":
      return `${senderUsername} liked ${originalPoster}'s post`;
    case "publicSpotAccepted":
      return "Your public submission was approved";
    case "friendRequest":
      if (status == "accepted") {
        if (invite != undefined && invite == true) {
          return `${senderUsername} accepted your invite and is now on sp0t!`;
        } else {
          return `${senderUsername} accepted your friend request`;
        }
      } else {
        return `${senderUsername} send you a friend request`;
      }
    default:
      return "";
  }
}
