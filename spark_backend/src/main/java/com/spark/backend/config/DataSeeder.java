package com.spark.backend.config;

import com.spark.backend.domain.*;
import com.spark.backend.entity.*;
import com.spark.backend.repository.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.UUID;

@Component
@Profile("!test")
public class DataSeeder implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(DataSeeder.class);
    private static final String GUEST_PHONE = "+910000000000";

    private final AppUserRepository users;
    private final FriendRequestRepository friendRequests;
    private final SparkEventRepository sparks;
    private final SparkParticipantRepository participants;
    private final SparkGroupRepository groups;
    private final SparkGroupMemberRepository groupMembers;

    public DataSeeder(AppUserRepository users,
                      FriendRequestRepository friendRequests,
                      SparkEventRepository sparks,
                      SparkParticipantRepository participants,
                      SparkGroupRepository groups,
                      SparkGroupMemberRepository groupMembers) {
        this.users = users;
        this.friendRequests = friendRequests;
        this.sparks = sparks;
        this.participants = participants;
        this.groups = groups;
        this.groupMembers = groupMembers;
    }

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        if (users.count() > 0) {
            log.info("[DataSeeder] Users already present — skipping.");
            return;
        }
        log.info("[DataSeeder] No users found — running seeder…");

        AppUserEntity guest = ensureGuest();

        List<AppUserEntity> friends = List.of(
                seedUser("+919876543210", "Arjun Mehta",   "ACTIVE",  "Cricket & chai lover ☕",  "cricket,badminton,food"),
                seedUser("+919876543211", "Priya Sharma",  "NONE",    "Design + dance 💃",         "dance,design,yoga"),
                seedUser("+919876543212", "Rohan Das",     "BUSY",    "Startup founder. Always building.", "startups,tech,running"),
                seedUser("+919876543213", "Neha Kapoor",   "ACTIVE",  "Travel & trekking 🏔️",     "trekking,travel,photography"),
                seedUser("+919876543214", "Karan Singh",   "NONE",    "Football & food. Nothing else.", "football,food,movies")
        );

        AppUserEntity stranger = seedUser("+919876543215", "Sneha Iyer", "NONE",
                "Books & coffee ☕", "books,coffee,movies");

        makeFriends(guest, friends);
        createPendingRequest(stranger, guest);

        SparkGroupEntity crew = seedGroup(guest, "Sunday Cricket Crew",
                "Weekly Sunday morning cricket gang 🏏",
                List.of(friends.get(0), friends.get(1), friends.get(4)));

        seedGroup(friends.get(2), "Tech & Build Club",
                "Builders, hackers, makers. All welcome.",
                List.of(guest, friends.get(3)));

        seedPastSpark(guest, "Cricket at Central Park",
                "sports", 19.0760, 72.8777,
                List.of(guest, friends.get(0), friends.get(4)), 3);

        seedPastSpark(friends.get(1), "Yoga on the terrace",
                "wellness", 19.0800, 72.8800,
                List.of(guest, friends.get(1), friends.get(3)), 5);

        seedPastSpark(guest, "Late night chai run",
                "food", 19.0725, 72.8710,
                List.of(guest, friends.get(0), friends.get(2)), 14);

        log.info("[DataSeeder] Done — guest user id={}", guest.getId());
    }

    private AppUserEntity ensureGuest() {
        return users.findByPhoneNumber(GUEST_PHONE).orElseGet(() -> {
            AppUserEntity u = new AppUserEntity();
            u.setPhoneNumber(GUEST_PHONE);
            u.setDisplayName("You (Guest)");
            u.setAvailabilityStatus("ACTIVE");
            return users.save(u);
        });
    }

    private AppUserEntity seedUser(String phone, String name, String availability,
                                   String bio, String interests) {
        return users.findByPhoneNumber(phone).orElseGet(() -> {
            AppUserEntity u = new AppUserEntity();
            u.setPhoneNumber(phone);
            u.setDisplayName(name);
            u.setAvailabilityStatus(availability);
            u.setBio(bio);
            u.setInterests(interests);
            return users.save(u);
        });
    }

    private void makeFriends(AppUserEntity a, List<AppUserEntity> others) {
        for (AppUserEntity b : others) {
            boolean exists = friendRequests
                    .findByFromUserIdAndToUserId(a.getId().toString(), b.getId().toString())
                    .isPresent();
            if (!exists) {
                FriendRequestEntity req = new FriendRequestEntity();
                req.setFromUserId(a.getId().toString());
                req.setToUserId(b.getId().toString());
                req.setStatus(FriendRequestStatus.ACCEPTED);
                req.setRespondedAt(Instant.now().minus(1, ChronoUnit.DAYS));
                friendRequests.save(req);
            }
        }
    }

    private void createPendingRequest(AppUserEntity from, AppUserEntity to) {
        boolean exists = friendRequests
                .findByFromUserIdAndToUserId(from.getId().toString(), to.getId().toString())
                .isPresent();
        if (!exists) {
            FriendRequestEntity req = new FriendRequestEntity();
            req.setFromUserId(from.getId().toString());
            req.setToUserId(to.getId().toString());
            req.setStatus(FriendRequestStatus.PENDING);
            req.setMessage("Hey! Found you on Spark — let's connect 👋");
            friendRequests.save(req);
        }
    }

    private SparkGroupEntity seedGroup(AppUserEntity owner, String name, String description,
                                       List<AppUserEntity> members) {
        if (groups.findByOwnerUserId(owner.getId().toString()).stream()
                .anyMatch(g -> g.getName().equals(name))) {
            return groups.findByOwnerUserId(owner.getId().toString()).stream()
                    .filter(g -> g.getName().equals(name)).findFirst().get();
        }

        SparkGroupEntity group = new SparkGroupEntity();
        group.setOwnerUserId(owner.getId().toString());
        group.setName(name);
        group.setDescription(description);
        SparkGroupEntity saved = groups.save(group);

        addMember(saved, owner, GroupMemberRole.OWNER);
        for (AppUserEntity m : members) {
            addMember(saved, m, GroupMemberRole.MEMBER);
        }
        return saved;
    }

    private void addMember(SparkGroupEntity group, AppUserEntity user, GroupMemberRole role) {
        SparkGroupMemberEntity m = new SparkGroupMemberEntity();
        m.setGroupId(group.getId());
        m.setUserId(user.getId().toString());
        m.setRole(role);
        groupMembers.save(m);
    }

    private void seedPastSpark(AppUserEntity host, String title, String category,
                               double lat, double lng,
                               List<AppUserEntity> attendees, int daysAgo) {
        Instant start = Instant.now().minus(daysAgo, ChronoUnit.DAYS);
        Instant end = start.plus(2, ChronoUnit.HOURS);

        SparkEventEntity spark = new SparkEventEntity();
        spark.setHostUserId(host.getId().toString());
        spark.setTitle(title);
        spark.setCategory(category);
        spark.setLocationName("Mumbai");
        spark.setLatitude(lat);
        spark.setLongitude(lng);
        spark.setStartsAt(start);
        spark.setEndsAt(end);
        spark.setMaxSpots(attendees.size());
        spark.setStatus(SparkStatus.ENDED);
        spark.setVisibility(SparkVisibility.PUBLIC);
        SparkEventEntity saved = sparks.save(spark);

        for (AppUserEntity u : attendees) {
            SparkParticipantEntity p = new SparkParticipantEntity();
            p.setSparkId(saved.getId());
            p.setUserId(u.getId().toString());
            p.setStatus(ParticipantStatus.JOINED);
            participants.save(p);
        }
    }
}
