const reveals = document.querySelectorAll(".reveal");
const radiusRange = document.querySelector("#radiusRange");
const radiusValue = document.querySelector("#radiusValue");
const chips = document.querySelectorAll(".chip");

const formFields = {
  title: document.querySelector("#sparkTitle"),
  category: document.querySelector("#sparkCategory"),
  time: document.querySelector("#sparkTime"),
  location: document.querySelector("#sparkLocation"),
  spots: document.querySelector("#sparkSpots"),
  radius: document.querySelector("#sparkRadius"),
};

const previewFields = {
  title: document.querySelector("#previewTitle"),
  category: document.querySelector("#previewCategoryTag"),
  time: document.querySelector("#previewTime"),
  location: document.querySelector("#previewLocation"),
  spots: document.querySelector("#previewSpots"),
  radius: document.querySelector("#previewRadius"),
};

if ("IntersectionObserver" in window) {
  const revealObserver = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add("is-visible");
          revealObserver.unobserve(entry.target);
        }
      });
    },
    {
      threshold: 0.18,
    }
  );

  reveals.forEach((item) => revealObserver.observe(item));
} else {
  reveals.forEach((item) => item.classList.add("is-visible"));
}

const tagClassMap = {
  Sports: "sports",
  Transit: "transit",
  Fun: "fun",
  Culture: "culture",
  Life: "life",
};

function syncRadius(value) {
  radiusValue.textContent = `${value} km`;
  formFields.radius.value = `${value} km around current location`;
  previewFields.radius.textContent = `${value} km radius`;
}

function syncPreview() {
  previewFields.title.textContent = formFields.title.value;
  previewFields.category.textContent = formFields.category.value;
  previewFields.time.textContent = formFields.time.value;
  previewFields.location.textContent = formFields.location.value;
  previewFields.spots.textContent = `${formFields.spots.value} spots open`;
  previewFields.radius.textContent = formFields.radius.value
    .replace("around current location", "radius")
    .trim();

  previewFields.category.className = "stream-tag";
  previewFields.category.classList.add(tagClassMap[formFields.category.value] || "sports");
}

radiusRange.addEventListener("input", (event) => {
  syncRadius(event.target.value);
});

chips.forEach((chip) => {
  chip.addEventListener("click", () => {
    chips.forEach((item) => item.classList.remove("active"));
    chip.classList.add("active");
    formFields.category.value = chip.dataset.category;
    syncPreview();
  });
});

Object.values(formFields).forEach((field) => {
  field.addEventListener("input", syncPreview);
});

syncRadius(radiusRange.value);
syncPreview();
