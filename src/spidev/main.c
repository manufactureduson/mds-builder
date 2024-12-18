#include <fcntl.h>
#include <getopt.h>
#include <linux/gpio.h>
#include <linux/spi/spidev.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <unistd.h>

#define SPI_MAX_TRANSFER_SIZE (4092)
#define SPI_MAX_DATA_SIZE (SPI_MAX_TRANSFER_SIZE - 6)
#define SPI_SPEED (90000000)

struct __attribute__((__packed__)) msg_t {
  uint16_t cmd;
  uint16_t len;
  uint16_t checksum;
  uint8_t data[SPI_MAX_DATA_SIZE];
};

uint16_t _checksum(uint8_t *data, uint16_t length) {
  uint16_t curr_crc = 0x0000;
  uint8_t sum1 = (uint8_t)curr_crc;
  uint8_t sum2 = (uint8_t)(curr_crc >> 8);
  int index;
  for (index = 0; index < length; index = index + 1) {
    sum1 = (sum1 + data[index]) % 255;
    sum2 = (sum2 + sum1) % 255;
  }
  return (sum2 << 8) | sum1;
}

static struct gpiohandle_request gpio_req;
static struct gpiohandle_data gpio_data;

int gpio_init(int n) {
  int val = 0;
  int gpio_fd;

  printf("init GPIO %d\n", n);
  gpio_fd = open("/dev/gpiochip0", 0);
  if (gpio_fd == -1) {
    fprintf(stderr, "Failed to open %s\n", "/dev/gpiochip0");
    perror("open");
    return -1;
  }

  gpio_req.lineoffsets[0] = n;
  gpio_req.lines = 1;
  gpio_req.flags = GPIOHANDLE_REQUEST_INPUT;
  strcpy(gpio_req.consumer_label, "spi_handshake");
  int ret = ioctl(gpio_fd, GPIO_GET_LINEHANDLE_IOCTL, &gpio_req);
  if (ret < 0) {
    perror("ioctl");
    return -1;
  }
  printf("fd: %d\n", gpio_req.fd);

  return gpio_fd;
}

int gpio_wait() {
  int val = 0;
  int ret;
  do {
    ret = ioctl(gpio_req.fd, GPIOHANDLE_GET_LINE_VALUES_IOCTL, &gpio_data);
    if (ret < 0) {
      perror("ioctl");
      return 0;
    }
    val = gpio_data.values[0];
  } while (!val);
}

int _transfer_file(int spidev, char *file_in, char *file_out, int speed) {

  struct msg_t sendbuf;
  struct msg_t recvbuf;

  struct spi_ioc_transfer tr = {
      .tx_buf = (unsigned long)&sendbuf,
      .rx_buf = (unsigned long)&recvbuf,
      .len = SPI_MAX_TRANSFER_SIZE,
      .delay_usecs = 0,
      .speed_hz = speed,
      .bits_per_word = 8,
  };

  FILE *fout = fopen(file_out, "w");
  if (fout == NULL) {
    perror("fopen");
    printf("Error opening file %s\n", file_out);
    return EXIT_FAILURE;
  }
  /* Open the file and mmap it */
  int fd_in = open(file_in, O_RDONLY);
  if (fd_in < 0) {
    perror("open");
    return EXIT_FAILURE;
  }

  // Get the size of the file
  off_t file_size = lseek(fd_in, 0, SEEK_END);
  if (file_size == -1) {
    perror("lseek");
    close(fd_in);
    return EXIT_FAILURE;
  }

  gpio_init(112);

  // Map the file into memory
  void *file_data = mmap(NULL, file_size, PROT_READ, MAP_PRIVATE, fd_in, 0);
  if (file_data == MAP_FAILED) {
    perror("mmap");
    close(fd_in);
    return EXIT_FAILURE;
  }

  /* Iterate the file and send it through SPI */
  size_t bytes_sent = 0;
  while (bytes_sent < file_size) {

    gpio_wait();

    /* Calculate the remaining bytes to send */
    size_t remaining_bytes = file_size - bytes_sent;

    /* Determine the number of bytes to send in this iteration */
    size_t bytes_to_send = remaining_bytes < SPI_MAX_DATA_SIZE
                               ? remaining_bytes
                               : SPI_MAX_DATA_SIZE;

    sendbuf.cmd = 0x01;
    sendbuf.len = bytes_to_send;

    /* Copy the data to the tx buffer */
    memcpy(sendbuf.data, file_data + bytes_sent, bytes_to_send);

    sendbuf.checksum = _checksum(sendbuf.data, sendbuf.len);

    // printf("|--> Sending: 0x%02x %d 0x%04x\n",sendbuf.cmd, sendbuf.len,
    // sendbuf.checksum);

    int ret = ioctl(spidev, SPI_IOC_MESSAGE(1), &tr);
    if (ret < 1)
      perror("can't send spi message");

    // printf("<--| Receiving: 0x%02x %d 0x%04x\n", recvbuf.cmd, recvbuf.len,
    // recvbuf.checksum);

    uint16_t checksum = _checksum(recvbuf.data, recvbuf.len);
    if (checksum != recvbuf.checksum) {
      fprintf(stderr, "Checksum error. Received: 0x%04x, Expected: 0x%04x\n",
              recvbuf.checksum, checksum);
      exit(EXIT_FAILURE);
    } else {
      /* Write the received data to the output file */
      // if (fwrite(recvbuf.data, sizeof(uint8_t), recvbuf.len, fout) !=
      // recvbuf.len) {
      //     perror("fwrite");
      //     fclose(fout);
      //     munmap(file_data, file_size);
      //     return EXIT_FAILURE;
      // }
    }

    /* Update the number of bytes sent */
    bytes_sent += bytes_to_send;
    // usleep(5000);
  }

  fclose(fout);

  // Close the file
  if (close(fd_in) < 0) {
    perror("close");
    munmap(file_data, file_size);
    return EXIT_FAILURE;
  }
}

static int spi_init(int speed, int mode) {
  /* Open SPI dev */
  int fd = open("/dev/spidev1.0", O_RDWR);
  if (fd < 0) {
    perror("open");
    goto err_fd;
  }

  /* Set SPI mode */

  if (ioctl(fd, SPI_IOC_WR_MODE, &mode) < 0) {
    perror("ioctl");
    goto err;
  }

  /* Read SPI Mode */
  if (ioctl(fd, SPI_IOC_RD_MODE, &mode) < 0) {
    perror("ioctl");
    goto err;
  }
  printf("SPI Mode: %d\n", mode);

  /* Set SPI speed */
  if (ioctl(fd, SPI_IOC_WR_MAX_SPEED_HZ, &speed) < 0) {
    perror("ioctl");
    goto err;
  }

  /* Read SPI speed */
  if (ioctl(fd, SPI_IOC_RD_MAX_SPEED_HZ, &speed) < 0) {
    perror("ioctl");
    goto err;
  }
  printf("SPI Speed: %d Hz\n", speed);
  /* Set the number of bits per word */
  int bits = 8;

  if (ioctl(fd, SPI_IOC_WR_BITS_PER_WORD, &bits) < 0) {
    perror("ioctl");
    goto err;
  }

  /* Read the number of bits per word */
  if (ioctl(fd, SPI_IOC_RD_BITS_PER_WORD, &bits) < 0) {
    perror("ioctl");
    goto err;
  }
  printf("SPI Bits: %d\n", bits);

  return fd;

err:
  close(fd);
err_fd:
  return -1;
}

static void spi_close(int fd) { close(fd); }

int main(int argc, char *argv[]) {
  int fd = -1;
  printf("SPI Master Test\n");

  /* Test if filename and SPI node are passed as arguments */

  int spi_mode = SPI_MODE_3;
  int opt;
  char *file_in = NULL;
  char *file_out = NULL;

  int spi_speed = SPI_SPEED;
  while ((opt = getopt(argc, argv, "m:s:i:o:")) != -1) {
    switch (opt) {
    case 'm':
      spi_mode = atoi(optarg);
      break;
    case 's':
      spi_speed = atoi(optarg) * 1000 * 1000;
      break;
    case 'i':
        file_in = optarg;
        break;
    case 'o':
        file_out = optarg;
        break;
    default:
      fprintf(stderr,
              "Usage: %s -m <spi_mode> -s <spi_speed> <file_in> <file_out> "
              "<spi_node>\n",
              argv[0]);
      return EXIT_FAILURE;
    }
  }

  fd = spi_init(spi_speed, spi_mode);

  /* transfer file passed as argument */
  _transfer_file(fd, file_in, file_out, spi_speed);

  /* Close SPI dev */
  spi_close(fd);

  return EXIT_SUCCESS;
}