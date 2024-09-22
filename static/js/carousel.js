function createCarousel(images) {
    const carousel = document.createElement('div');
    carousel.className = 'carousel';
    let currentIndex = 0;

    // Create main image container
    const mainImageContainer = document.createElement('div');
    mainImageContainer.className = 'carousel-main-image';
    carousel.appendChild(mainImageContainer);

    // Create vignette container
    const vignetteContainer = document.createElement('div');
    vignetteContainer.className = 'carousel-vignettes';
    carousel.appendChild(vignetteContainer);

    // Function to update the main displayed image
    function updateMainImage() {
        mainImageContainer.innerHTML = '';
        const img = document.createElement('img');
        img.src = images[currentIndex];
        img.style.width = '100%';
        img.style.height = 'auto';
        mainImageContainer.appendChild(img);
    }

    // Function to create vignettes
    function createVignettes() {
        vignetteContainer.innerHTML = '';
        const containerWidth = carousel.offsetWidth;
        const vignetteWidth = 120;
        const vignetteHeight = 80;
        const vignetteMargin = 10;
        const maxVignettes = Math.floor(containerWidth / (vignetteWidth + vignetteMargin));

        const startIndex = Math.max(0, currentIndex - Math.floor(maxVignettes / 2));
        const endIndex = Math.min(images.length, startIndex + maxVignettes);

        for (let i = startIndex; i < endIndex; i++) {
            const vignette = document.createElement('div');
            vignette.className = 'vignette';
            if (i === currentIndex) vignette.classList.add('active');

            const img = document.createElement('img');
            img.src = images[i];
            img.style.width = vignetteWidth + 'px';
            img.style.height = vignetteHeight + 'px';
            img.style.objectFit = 'cover';

            vignette.appendChild(img);
            vignette.addEventListener('click', () => goToImage(i));
            vignetteContainer.appendChild(vignette);
        }
    }

    // Function to go to a specific image
    function goToImage(index) {
        currentIndex = index;
        updateMainImage();
        createVignettes();
    }

    // Function to go to the next image
    function nextImage() {
        currentIndex = (currentIndex + 1) % images.length;
        updateMainImage();
        createVignettes();
    }

    // Function to go to the previous image
    function prevImage() {
        currentIndex = (currentIndex - 1 + images.length) % images.length;
        updateMainImage();
        createVignettes();
    }

    // Event listener for keyboard navigation
    document.addEventListener('keydown', (e) => {
        if (e.key === 'ArrowRight') nextImage();
        if (e.key === 'ArrowLeft') prevImage();
    });

    // Initialize the carousel
    updateMainImage();

    // Use setTimeout to delay the initial creation of vignettes
    setTimeout(() => {
        createVignettes();
    }, 0);

    // Recalculate vignettes on window resize
    window.addEventListener('resize', createVignettes);

    return carousel;
}

// Function to initialize the carousel with specific images
function initializeCarousel(containerId, images) {
    document.addEventListener('DOMContentLoaded', () => {
        const container = document.getElementById(containerId);
        if (container) {
            const carouselElement = createCarousel(images);
            container.appendChild(carouselElement);

            // Use ResizeObserver to detect when the carousel is fully rendered
            const resizeObserver = new ResizeObserver(entries => {
                for (let entry of entries) {
                    if (entry.target === carouselElement) {
                        createVignettes();
                        resizeObserver.disconnect(); // Stop observing once vignettes are created
                    }
                }
            });

            resizeObserver.observe(carouselElement);
        } else {
            console.error(`Container with id "${containerId}" not found.`);
        }
    });
}

// Make the initializeCarousel function globally available
window.initializeCarousel = initializeCarousel;
