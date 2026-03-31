package com.spark.backend.service;

import com.spark.backend.entity.SafetyAlertEntity;
import com.spark.backend.repository.SafetyAlertRepository;
import jakarta.transaction.Transactional;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.UUID;

@Service
public class SafetyService {
    private final SafetyAlertRepository safetyAlertRepository;

    public SafetyService(SafetyAlertRepository safetyAlertRepository) {
        this.safetyAlertRepository = safetyAlertRepository;
    }

    public List<String> guidelines() {
        return List.of(
                "Meet only in public, well-lit places and avoid isolated areas.",
                "Share spark details with a trusted contact before you go.",
                "For women and vulnerable participants: prefer verified hosts and daytime/public meetup points.",
                "Do not share personal financial details, passwords, or OTPs with anyone.",
                "If anything feels unsafe, leave immediately and trigger SOS in the app."
        );
    }

    @Transactional
    public SafetyAlertEntity createAlert(CreateSafetyAlertCommand command) {
        SafetyAlertEntity entity = new SafetyAlertEntity();
        entity.setUserId(command.userId());
        entity.setSparkId(command.sparkId());
        entity.setLocationName(command.locationName());
        entity.setNote(command.note());
        entity.setStatus("OPEN");
        return safetyAlertRepository.save(entity);
    }

    public record CreateSafetyAlertCommand(
            String userId,
            UUID sparkId,
            String locationName,
            String note
    ) {
    }
}
