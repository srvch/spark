package com.spark.backend.service;

import com.spark.backend.entity.UserDeviceTokenEntity;
import com.spark.backend.repository.UserDeviceTokenRepository;
import jakarta.transaction.Transactional;
import org.springframework.stereotype.Service;

@Service
public class DeviceTokenService {
    private final UserDeviceTokenRepository userDeviceTokenRepository;

    public DeviceTokenService(UserDeviceTokenRepository userDeviceTokenRepository) {
        this.userDeviceTokenRepository = userDeviceTokenRepository;
    }

    @Transactional
    public void register(String userId, String token, String platform) {
        UserDeviceTokenEntity entity = userDeviceTokenRepository.findById(token).orElseGet(UserDeviceTokenEntity::new);
        entity.setToken(token);
        entity.setUserId(userId);
        entity.setPlatform(platform);
        entity.setActive(true);
        userDeviceTokenRepository.save(entity);
    }

    @Transactional
    public void unregister(String userId, String token) {
        UserDeviceTokenEntity entity = userDeviceTokenRepository.findById(token)
                .orElseThrow(() -> new IllegalArgumentException("Token not found"));
        if (!entity.getUserId().equals(userId)) {
            throw new IllegalArgumentException("Cannot remove another user's device token.");
        }
        entity.setActive(false);
        userDeviceTokenRepository.save(entity);
    }
}
