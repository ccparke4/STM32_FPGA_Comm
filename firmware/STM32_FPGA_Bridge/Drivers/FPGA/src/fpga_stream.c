/**
 * @file    fpga_stream.c
 * @brief   FPGA Data Plane Driver Implementation
 */

#include "fpga_stream.h"
#include "main.h" // For SPI_CS_Pin definitions

/* Private Variables */
static SPI_HandleTypeDef *stream_hspi = NULL;
volatile bool stream_dma_flag = false;

/* Hardware Macros (Mapped to main.h defines) */
#define CS_LOW()  HAL_GPIO_WritePin(SPI_CS_GPIO_Port, SPI_CS_Pin, GPIO_PIN_RESET)
#define CS_HIGH() HAL_GPIO_WritePin(SPI_CS_GPIO_Port, SPI_CS_Pin, GPIO_PIN_SET)

stream_status_t fpga_stream_init(SPI_HandleTypeDef *hspi) {
    if (hspi == NULL) return STREAM_ERROR;

    stream_hspi = hspi;
    CS_HIGH();
    return STREAM_OK;
}

stream_status_t fpga_stream_start(uint8_t *tx_buf, uint8_t *rx_buf, uint16_t len) {
    if (stream_hspi == NULL) return STREAM_ERROR;

    // Assert CS (active low)
    CS_LOW();

    // Start DMA in circular mode
    HAL_StatusTypeDef status = HAL_SPI_TransmitReceive_DMA(stream_hspi, tx_buf, rx_buf, len);

    if (status != HAL_OK) {
        CS_HIGH();              // ABORT
        return STREAM_ERROR;
    }

    return STREAM_OK;
}

stream_status_t fpga_stream_stop(void) {
    if (stream_hspi == NULL) return STREAM_ERROR;

    HAL_SPI_DMAStop(stream_hspi);
    CS_HIGH();
    return STREAM_OK;
}

void fpga_stream_cs_control(bool active) {
    if (active) {
        CS_LOW();
    } else {
        CS_HIGH();
    }
}

bool fpga_stream_check_complete(void) {
    return stream_dma_flag;
}

void fpga_stream_clear_complete(void) {
    stream_dma_flag = false;
}


/* HAL callbacks (linked from stm32h7xx_it.c or main.c) */
void HAL_SPI_TxRxCpltCallback(SPI_HandleTypeDef *hspi) {
    if (hspi == stream_hspi) {
        stream_dma_flag = true;
    }
}